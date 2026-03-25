#!/usr/bin/env python3
"""MCP stdio server for industrial vision inspection.

Tools: capture_frame, detect_defects, segment_region, compare_images, inspection_report.

Camera capture: cv2.VideoCapture (RTSP/USB), fallback to PIL image loading.
Detection: ultralytics YOLOv8, fallback to mock stub.
Comparison: skimage structural_similarity, fallback to pixel-diff stub.
"""

from __future__ import annotations

import base64
import io
import json
import os
import sys
import time
import uuid
from pathlib import Path
from typing import Any

# Add parent dir for mcp_stdio import
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from mcp_stdio import (  # type: ignore
    PROTOCOL_VERSION,
    error_tool_result,
    make_error,
    make_response,
    ok_tool_result,
    read_message,
    write_message,
)

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

DEFAULT_MODEL_PATH = os.getenv("YOLO_MODEL", "yolov8n.pt")
CAPTURE_DIR = os.getenv("VISION_CAPTURE_DIR", "/tmp/vision_captures")
CONFIDENCE_THRESHOLD = float(os.getenv("VISION_CONFIDENCE", "0.25"))

# ---------------------------------------------------------------------------
# Optional imports with graceful fallback
# ---------------------------------------------------------------------------

_HAS_CV2 = False
_HAS_ULTRALYTICS = False
_HAS_PIL = False
_HAS_SKIMAGE = False
_HAS_NUMPY = False

try:
    import cv2  # type: ignore

    _HAS_CV2 = True
except ImportError:
    pass

try:
    from ultralytics import YOLO  # type: ignore

    _HAS_ULTRALYTICS = True
except ImportError:
    pass

try:
    from PIL import Image  # type: ignore

    _HAS_PIL = True
except ImportError:
    pass

try:
    from skimage.metrics import structural_similarity as ssim  # type: ignore

    _HAS_SKIMAGE = True
except ImportError:
    pass

try:
    import numpy as np  # type: ignore

    _HAS_NUMPY = True
except ImportError:
    pass

# ---------------------------------------------------------------------------
# Server info
# ---------------------------------------------------------------------------

SERVER_NAME = "vision-inspector"
SERVER_VERSION = "1.0.0"

# ---------------------------------------------------------------------------
# Tools schema
# ---------------------------------------------------------------------------

TOOLS = [
    {
        "name": "capture_frame",
        "description": (
            "Capture a single frame from an RTSP stream, USB camera (by index), "
            "or load from a local image file. Returns the saved file path and base64 thumbnail."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "source": {
                    "type": "string",
                    "description": (
                        "RTSP URL (rtsp://...), USB camera index as string ('0', '1'), "
                        "or path to a local image file."
                    ),
                },
                "output_path": {
                    "type": "string",
                    "description": "Optional output file path. Defaults to auto-generated in VISION_CAPTURE_DIR.",
                    "default": "",
                },
            },
            "required": ["source"],
        },
    },
    {
        "name": "detect_defects",
        "description": (
            "Run YOLOv8 object detection on an image to find defects, parts, or objects. "
            "Returns bounding boxes, class names, and confidence scores."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "image_path": {
                    "type": "string",
                    "description": "Path to the image file to analyze.",
                },
                "model_path": {
                    "type": "string",
                    "description": f"Path to YOLOv8 model (.pt). Default: {DEFAULT_MODEL_PATH}",
                    "default": DEFAULT_MODEL_PATH,
                },
                "confidence": {
                    "type": "number",
                    "description": f"Minimum confidence threshold (0-1). Default: {CONFIDENCE_THRESHOLD}",
                    "default": CONFIDENCE_THRESHOLD,
                },
                "classes": {
                    "type": "array",
                    "items": {"type": "integer"},
                    "description": "Optional list of class IDs to filter. Empty = all classes.",
                    "default": [],
                },
            },
            "required": ["image_path"],
        },
    },
    {
        "name": "segment_region",
        "description": (
            "Segment a region of interest in an image using bounding-box crop. "
            "Extracts the region, optionally applies thresholding for defect isolation. "
            "SAM2-style bbox-based segmentation."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "image_path": {
                    "type": "string",
                    "description": "Path to the source image.",
                },
                "bbox": {
                    "type": "object",
                    "description": "Bounding box: {x1, y1, x2, y2} in pixels.",
                    "properties": {
                        "x1": {"type": "integer"},
                        "y1": {"type": "integer"},
                        "x2": {"type": "integer"},
                        "y2": {"type": "integer"},
                    },
                    "required": ["x1", "y1", "x2", "y2"],
                },
                "threshold": {
                    "type": "integer",
                    "description": "Binary threshold value (0-255) for defect isolation. 0 = no thresholding.",
                    "default": 0,
                },
                "output_path": {
                    "type": "string",
                    "description": "Optional output path for the segmented region.",
                    "default": "",
                },
            },
            "required": ["image_path", "bbox"],
        },
    },
    {
        "name": "compare_images",
        "description": (
            "Compare two images for differences using structural similarity (SSIM). "
            "Returns similarity score, difference map path, and changed regions."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "image_a": {
                    "type": "string",
                    "description": "Path to the reference (golden) image.",
                },
                "image_b": {
                    "type": "string",
                    "description": "Path to the test image to compare.",
                },
                "output_diff_path": {
                    "type": "string",
                    "description": "Optional path to save the difference heatmap.",
                    "default": "",
                },
            },
            "required": ["image_a", "image_b"],
        },
    },
    {
        "name": "inspection_report",
        "description": (
            "Generate an inspection report from detection results. "
            "Summarizes pass/fail status, defect counts, severity, and recommendations."
        ),
        "inputSchema": {
            "type": "object",
            "properties": {
                "detections": {
                    "type": "array",
                    "items": {
                        "type": "object",
                        "properties": {
                            "class_name": {"type": "string"},
                            "confidence": {"type": "number"},
                            "bbox": {
                                "type": "object",
                                "properties": {
                                    "x1": {"type": "number"},
                                    "y1": {"type": "number"},
                                    "x2": {"type": "number"},
                                    "y2": {"type": "number"},
                                },
                            },
                        },
                    },
                    "description": "List of detection results (from detect_defects).",
                },
                "similarity_score": {
                    "type": "number",
                    "description": "Optional SSIM score from compare_images (0-1).",
                    "default": -1,
                },
                "part_id": {
                    "type": "string",
                    "description": "Optional part/batch identifier.",
                    "default": "",
                },
                "threshold_pass": {
                    "type": "number",
                    "description": "Minimum confidence for a detection to count as a defect. Default: 0.5",
                    "default": 0.5,
                },
                "max_defects_pass": {
                    "type": "integer",
                    "description": "Maximum number of defects before marking as FAIL. Default: 0 (zero tolerance).",
                    "default": 0,
                },
            },
            "required": ["detections"],
        },
    },
]

# ---------------------------------------------------------------------------
# Tool implementations
# ---------------------------------------------------------------------------


def _ensure_capture_dir() -> None:
    Path(CAPTURE_DIR).mkdir(parents=True, exist_ok=True)


def _load_image_as_array(path: str) -> Any:
    """Load an image as a numpy-like array. Uses cv2 if available, else PIL."""
    if _HAS_CV2:
        img = cv2.imread(path)
        if img is None:
            raise FileNotFoundError(f"Cannot read image: {path}")
        return img
    if _HAS_PIL and _HAS_NUMPY:
        img = Image.open(path)
        return np.array(img)
    raise RuntimeError("No image library available (need opencv-python or Pillow+numpy)")


def _image_to_base64_thumbnail(img: Any, max_size: int = 256) -> str:
    """Convert image array to base64 JPEG thumbnail."""
    if _HAS_CV2:
        h, w = img.shape[:2]
        scale = min(max_size / w, max_size / h, 1.0)
        thumb = cv2.resize(img, (int(w * scale), int(h * scale)))
        _, buf = cv2.imencode(".jpg", thumb, [cv2.IMWRITE_JPEG_QUALITY, 70])
        return base64.b64encode(buf.tobytes()).decode("ascii")
    if _HAS_PIL:
        pil_img = Image.fromarray(img) if _HAS_NUMPY else img
        pil_img.thumbnail((max_size, max_size))
        buf = io.BytesIO()
        pil_img.save(buf, format="JPEG", quality=70)
        return base64.b64encode(buf.getvalue()).decode("ascii")
    return ""


def tool_capture_frame(args: dict[str, Any]) -> dict[str, Any]:
    """Capture a frame from camera or load from file."""
    _ensure_capture_dir()
    source = args["source"]
    output_path = args.get("output_path", "")

    if not output_path:
        output_path = str(Path(CAPTURE_DIR) / f"capture_{uuid.uuid4().hex[:8]}.jpg")

    # Try to interpret as camera index
    is_camera = False
    cam_index = -1
    try:
        cam_index = int(source)
        is_camera = True
    except ValueError:
        if source.startswith("rtsp://") or source.startswith("http://"):
            is_camera = True

    if is_camera:
        if not _HAS_CV2:
            return {
                "status": "mock",
                "message": "cv2 not available — returning mock capture",
                "output_path": output_path,
                "width": 1920,
                "height": 1080,
                "timestamp": time.time(),
                "thumbnail_b64": "",
            }

        cap = cv2.VideoCapture(cam_index if cam_index >= 0 else source)
        if not cap.isOpened():
            raise RuntimeError(f"Cannot open camera source: {source}")

        ret, frame = cap.read()
        cap.release()
        if not ret:
            raise RuntimeError(f"Failed to capture frame from: {source}")

        cv2.imwrite(output_path, frame)
        h, w = frame.shape[:2]
        return {
            "status": "ok",
            "output_path": output_path,
            "width": w,
            "height": h,
            "timestamp": time.time(),
            "thumbnail_b64": _image_to_base64_thumbnail(frame),
        }
    else:
        # Load from file
        img = _load_image_as_array(source)
        if _HAS_CV2:
            cv2.imwrite(output_path, img)
            h, w = img.shape[:2]
        elif _HAS_PIL:
            pil_img = Image.open(source)
            pil_img.save(output_path)
            w, h = pil_img.size
            img = pil_img
        else:
            raise RuntimeError("No image library available")

        return {
            "status": "ok",
            "output_path": output_path,
            "width": w,
            "height": h,
            "timestamp": time.time(),
            "thumbnail_b64": _image_to_base64_thumbnail(img) if _HAS_CV2 or _HAS_PIL else "",
        }


def tool_detect_defects(args: dict[str, Any]) -> dict[str, Any]:
    """Run YOLOv8 detection on an image."""
    image_path = args["image_path"]
    model_path = args.get("model_path", DEFAULT_MODEL_PATH)
    confidence = args.get("confidence", CONFIDENCE_THRESHOLD)
    classes = args.get("classes", [])

    if not Path(image_path).is_file():
        raise FileNotFoundError(f"Image not found: {image_path}")

    if _HAS_ULTRALYTICS:
        model = YOLO(model_path)
        results = model(image_path, conf=confidence, classes=classes or None, verbose=False)
        detections = []
        for r in results:
            for box in r.boxes:
                cls_id = int(box.cls[0])
                cls_name = r.names.get(cls_id, f"class_{cls_id}")
                conf = float(box.conf[0])
                x1, y1, x2, y2 = [float(v) for v in box.xyxy[0]]
                detections.append({
                    "class_id": cls_id,
                    "class_name": cls_name,
                    "confidence": round(conf, 4),
                    "bbox": {"x1": round(x1, 1), "y1": round(y1, 1), "x2": round(x2, 1), "y2": round(y2, 1)},
                })
        return {
            "status": "ok",
            "model": model_path,
            "image": image_path,
            "detection_count": len(detections),
            "detections": detections,
        }
    else:
        # Mock stub for environments without ultralytics
        return {
            "status": "mock",
            "model": model_path,
            "image": image_path,
            "message": "ultralytics not installed — returning mock detections",
            "detection_count": 2,
            "detections": [
                {
                    "class_id": 0,
                    "class_name": "scratch",
                    "confidence": 0.87,
                    "bbox": {"x1": 120.0, "y1": 80.0, "x2": 250.0, "y2": 130.0},
                },
                {
                    "class_id": 1,
                    "class_name": "dent",
                    "confidence": 0.62,
                    "bbox": {"x1": 400.0, "y1": 300.0, "x2": 480.0, "y2": 370.0},
                },
            ],
        }


def tool_segment_region(args: dict[str, Any]) -> dict[str, Any]:
    """Segment a bounding-box region from an image."""
    _ensure_capture_dir()
    image_path = args["image_path"]
    bbox = args["bbox"]
    threshold = args.get("threshold", 0)
    output_path = args.get("output_path", "")

    if not output_path:
        output_path = str(Path(CAPTURE_DIR) / f"segment_{uuid.uuid4().hex[:8]}.jpg")

    x1, y1, x2, y2 = bbox["x1"], bbox["y1"], bbox["x2"], bbox["y2"]

    if _HAS_CV2:
        img = cv2.imread(image_path)
        if img is None:
            raise FileNotFoundError(f"Cannot read image: {image_path}")
        crop = img[y1:y2, x1:x2]
        if threshold > 0:
            gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)
            _, mask = cv2.threshold(gray, threshold, 255, cv2.THRESH_BINARY)
            # Apply mask
            crop = cv2.bitwise_and(crop, crop, mask=mask)
        cv2.imwrite(output_path, crop)
        h, w = crop.shape[:2]
        return {
            "status": "ok",
            "output_path": output_path,
            "region_width": w,
            "region_height": h,
            "bbox": bbox,
            "threshold_applied": threshold > 0,
        }
    elif _HAS_PIL:
        img = Image.open(image_path)
        crop = img.crop((x1, y1, x2, y2))
        crop.save(output_path)
        return {
            "status": "ok",
            "output_path": output_path,
            "region_width": x2 - x1,
            "region_height": y2 - y1,
            "bbox": bbox,
            "threshold_applied": False,
            "note": "PIL fallback — no thresholding applied",
        }
    else:
        return {
            "status": "mock",
            "message": "No image library available — returning mock segment",
            "output_path": output_path,
            "region_width": x2 - x1,
            "region_height": y2 - y1,
            "bbox": bbox,
        }


def tool_compare_images(args: dict[str, Any]) -> dict[str, Any]:
    """Compare two images using structural similarity."""
    _ensure_capture_dir()
    image_a = args["image_a"]
    image_b = args["image_b"]
    output_diff_path = args.get("output_diff_path", "")

    if not output_diff_path:
        output_diff_path = str(Path(CAPTURE_DIR) / f"diff_{uuid.uuid4().hex[:8]}.jpg")

    if _HAS_CV2 and _HAS_NUMPY and _HAS_SKIMAGE:
        img_a = cv2.imread(image_a, cv2.IMREAD_GRAYSCALE)
        img_b = cv2.imread(image_b, cv2.IMREAD_GRAYSCALE)
        if img_a is None:
            raise FileNotFoundError(f"Cannot read image: {image_a}")
        if img_b is None:
            raise FileNotFoundError(f"Cannot read image: {image_b}")

        # Resize B to match A if needed
        if img_a.shape != img_b.shape:
            img_b = cv2.resize(img_b, (img_a.shape[1], img_a.shape[0]))

        score, diff = ssim(img_a, img_b, full=True)
        diff_uint8 = (255 - (diff * 255)).astype(np.uint8)
        cv2.imwrite(output_diff_path, diff_uint8)

        # Find contours of changed regions
        _, thresh = cv2.threshold(diff_uint8, 50, 255, cv2.THRESH_BINARY)
        contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        changed_regions = []
        for c in contours:
            x, y, w, h = cv2.boundingRect(c)
            area = cv2.contourArea(c)
            if area > 100:  # filter noise
                changed_regions.append({"x": x, "y": y, "w": w, "h": h, "area": int(area)})

        return {
            "status": "ok",
            "ssim_score": round(float(score), 4),
            "diff_map_path": output_diff_path,
            "changed_region_count": len(changed_regions),
            "changed_regions": changed_regions[:20],  # cap at 20
            "identical": score > 0.98,
        }
    elif _HAS_PIL and _HAS_NUMPY:
        # Simple pixel-diff fallback
        img_a = np.array(Image.open(image_a).convert("L"))
        img_b_raw = Image.open(image_b).convert("L")
        img_b = np.array(img_b_raw.resize((img_a.shape[1], img_a.shape[0])))
        diff = np.abs(img_a.astype(float) - img_b.astype(float))
        mean_diff = float(np.mean(diff))
        score = max(0.0, 1.0 - mean_diff / 255.0)
        diff_img = Image.fromarray(diff.astype(np.uint8))
        diff_img.save(output_diff_path)
        return {
            "status": "ok",
            "ssim_score": round(score, 4),
            "diff_map_path": output_diff_path,
            "changed_region_count": -1,
            "changed_regions": [],
            "identical": score > 0.98,
            "note": "PIL+numpy fallback — pixel mean diff, not true SSIM",
        }
    else:
        return {
            "status": "mock",
            "message": "No image comparison libraries available — returning mock result",
            "ssim_score": 0.92,
            "diff_map_path": output_diff_path,
            "changed_region_count": 3,
            "changed_regions": [
                {"x": 100, "y": 200, "w": 50, "h": 30, "area": 1200},
                {"x": 400, "y": 150, "w": 20, "h": 25, "area": 400},
                {"x": 300, "y": 350, "w": 35, "h": 40, "area": 1100},
            ],
            "identical": False,
        }


def tool_inspection_report(args: dict[str, Any]) -> dict[str, Any]:
    """Generate an inspection report from detection results."""
    detections = args.get("detections", [])
    similarity_score = args.get("similarity_score", -1)
    part_id = args.get("part_id", "")
    threshold_pass = args.get("threshold_pass", 0.5)
    max_defects_pass = args.get("max_defects_pass", 0)

    # Filter significant detections
    significant = [d for d in detections if d.get("confidence", 0) >= threshold_pass]
    defect_count = len(significant)

    # Classify severity
    severity_map: dict[str, list[dict]] = {"critical": [], "major": [], "minor": []}
    for d in significant:
        conf = d.get("confidence", 0)
        if conf >= 0.9:
            severity_map["critical"].append(d)
        elif conf >= 0.7:
            severity_map["major"].append(d)
        else:
            severity_map["minor"].append(d)

    # Pass/fail decision
    passed = defect_count <= max_defects_pass
    if similarity_score >= 0 and similarity_score < 0.85:
        passed = False

    # Build class summary
    class_counts: dict[str, int] = {}
    for d in significant:
        cn = d.get("class_name", "unknown")
        class_counts[cn] = class_counts.get(cn, 0) + 1

    # Recommendations
    recommendations = []
    if severity_map["critical"]:
        recommendations.append("URGENT: Critical defects detected — quarantine part and escalate to QA lead.")
    if severity_map["major"]:
        recommendations.append("Major defects found — rework or reject part per SOP.")
    if similarity_score >= 0 and similarity_score < 0.85:
        recommendations.append(f"Visual deviation detected (SSIM={similarity_score:.3f}) — compare with golden sample.")
    if passed:
        recommendations.append("Part passes quality inspection — release to next stage.")

    report = {
        "status": "ok",
        "timestamp": time.time(),
        "part_id": part_id or "N/A",
        "verdict": "PASS" if passed else "FAIL",
        "total_detections": len(detections),
        "significant_defects": defect_count,
        "severity": {
            "critical": len(severity_map["critical"]),
            "major": len(severity_map["major"]),
            "minor": len(severity_map["minor"]),
        },
        "class_summary": class_counts,
        "similarity_score": round(similarity_score, 4) if similarity_score >= 0 else None,
        "thresholds": {
            "confidence_pass": threshold_pass,
            "max_defects_pass": max_defects_pass,
        },
        "recommendations": recommendations,
    }
    return report


# ---------------------------------------------------------------------------
# MCP dispatcher
# ---------------------------------------------------------------------------

TOOL_DISPATCH = {
    "capture_frame": tool_capture_frame,
    "detect_defects": tool_detect_defects,
    "segment_region": tool_segment_region,
    "compare_images": tool_compare_images,
    "inspection_report": tool_inspection_report,
}


def handle_request(req: dict[str, Any]) -> dict[str, Any] | None:
    method = req.get("method", "")
    req_id = req.get("id")

    if method == "initialize":
        return make_response(req_id, {
            "protocolVersion": PROTOCOL_VERSION,
            "capabilities": {"tools": {"listChanged": False}},
            "serverInfo": {"name": SERVER_NAME, "version": SERVER_VERSION},
        })

    if method == "notifications/initialized":
        return None

    if method == "tools/list":
        return make_response(req_id, {"tools": TOOLS})

    if method == "tools/call":
        tool_name = req.get("params", {}).get("name", "")
        arguments = req.get("params", {}).get("arguments", {})
        handler = TOOL_DISPATCH.get(tool_name)
        if not handler:
            return make_response(req_id, error_tool_result(
                f"Unknown tool: {tool_name}",
                {"error": f"Unknown tool: {tool_name}"},
            ))
        try:
            result = handler(arguments)
            summary = json.dumps(result, indent=2)
            return make_response(req_id, ok_tool_result(summary, result))
        except Exception as exc:
            return make_response(req_id, error_tool_result(
                f"Error in {tool_name}: {exc}",
                {"error": str(exc), "tool": tool_name},
            ))

    return make_error(req_id, -32601, f"Unknown method: {method}")


def main() -> None:
    """MCP stdio main loop — reads JSON-RPC over stdin, writes to stdout."""
    backends = []
    if _HAS_CV2:
        backends.append("opencv")
    if _HAS_ULTRALYTICS:
        backends.append("ultralytics/YOLOv8")
    if _HAS_PIL:
        backends.append("Pillow")
    if _HAS_SKIMAGE:
        backends.append("scikit-image/SSIM")
    if _HAS_NUMPY:
        backends.append("numpy")
    if not backends:
        backends.append("mock-only")

    sys.stderr.write(f"[{SERVER_NAME}] Starting MCP server v{SERVER_VERSION} — backends: {', '.join(backends)}\n")
    sys.stderr.flush()

    while True:
        msg = read_message()
        if msg is None:
            break
        resp = handle_request(msg)
        if resp is not None:
            write_message(resp)


if __name__ == "__main__":
    main()
