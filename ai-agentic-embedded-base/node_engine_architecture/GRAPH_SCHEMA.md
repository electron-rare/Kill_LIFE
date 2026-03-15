# Graph Schema Specification

## Structure

{
  "nodes": [],
  "connections": []
}

---

## Node

{
  "id": "node_id",
  "type": "node_type",
  "params": {},
  "runtime": "local_cpu"
}

---

## Connection

{
  "from": ["node_id","output"],
  "to": ["node_id","input"]
}

---

## Example

{
  "nodes": [
    {"id":"dataset","type":"dataset_file"},
    {"id":"clean","type":"clean_text"},
    {"id":"train","type":"lora_training"}
  ],
  "connections":[
    {"from":["dataset","out"],"to":["clean","dataset"]},
    {"from":["clean","dataset"],"to":["train","dataset"]}
  ]
}
