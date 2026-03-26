* Kill_LIFE — LDO AMS1117-3.3 Transient Analysis
* Board: Waveshare ESP32-S3-LCD-1.85
* Purpose: Validate 3.3V output regulation under ESP32-S3 load transients
*
* Load profile:
*   - Idle: 30mA
*   - WiFi TX burst: 350mA peak, 5ms duration
*   - Audio (PCM5101A) + LCD: +70mA after 10ms
*
* AMS1117-3.3 key specs:
*   - Vout: 3.3V ±1%
*   - Iout max: 800mA
*   - Dropout: ~0.5V @ 200mA
*   - Cout min: 10µF (stability requirement)

* ---- Input supply ----
V_USB  VIN  GND  DC 5.0    ; USB 5V

* ---- AMS1117-3.3 simplified macro model ----
* Ideal regulated output: 3.3V source with output impedance
V_LDO  VREG  GND  DC 3.3
R_LDO  VREG  VOUT  0.3     ; LDO Zout (0.3Ω typical)

* Output capacitor — 10µF MLCC (ESR in series)
R_ESR  VOUT  VCAP  0.05    ; ESR ~50mΩ for MLCC
C_OUT  VCAP  GND   10uF

* ---- PCB trace: LDO output to ESP32-S3 VDD pins (series L+R) ----
L_TRACE  VOUT  VMID  8nH
R_TRACE  VMID  VPWR  0.01

* ---- Decoupling at ESP32-S3 VDD pins ----
C_DEC1  VPWR  GND  100nF
C_DEC2  VPWR  GND  10uF
C_DEC3  VPWR  GND  100nF
C_DEC4  VPWR  GND  10uF

* ---- Load models ----
* Base load: 30mA idle (CPU idle, WiFi off)
R_IDLE  VPWR  GND  110     ; 3.3V / 30mA ≈ 110Ω

* WiFi TX burst: 320mA extra at t=1ms, 5ms pulse
I_WIFI  VPWR  GND  PULSE(0 0.32 1m 100u 100u 5m 30m)

* Audio + LCD: 70mA extra starting at t=10ms
I_AUDIO  VPWR  GND  PULSE(0 0.07 10m 1m 1m 100m 200m)

* ---- Transient analysis ----
.tran 10u 25m

.control
run
print V(VOUT) V(VPWR)
* Voltage droop during WiFi burst (should stay > 3.135V = 3.3V - 5%)
meas tran v_droop MIN v(vpwr) from=1m to=7m
* Steady-state after settling
meas tran v_steady AVG v(vpwr) from=18m to=22m
print v_droop v_steady
quit
.endc

.end
