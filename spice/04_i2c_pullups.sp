* Kill_LIFE I2C Bus Pull-up Analysis
* ESP32-S3 I2C: SDA=GPIO1, SCL=GPIO2 (or remapped)
* Devices on bus: LCD touch controller, optional sensors
* Pull-up: 4.7kΩ to 3.3V (standard Fast-mode 400kHz)
*
* Goal: Verify rise time meets I2C spec (≤300ns for Fast-mode)
* I2C Fast-mode spec: Vcc=3.3V, tr≤300ns, Cb≤400pF
*
* Model: GPIO open-drain (pulls low via NMOS), releases to Rpu

* --- Supply ---
V_VDD VDD GND DC 3.3V

* --- Pull-up resistors ---
R_SDA_PU VDD SDA 4.7k
R_SCL_PU VDD SCL 4.7k

* --- Bus capacitance ---
* PCB trace (~50pF) + device input caps (4 devices × ~10pF each)
C_SDA SDA GND 90pF
C_SCL SCL GND 90pF

* --- GPIO open-drain model (ESP32-S3 NMOS pull-down) ---
* Active low: pulls SDA to ~100mV with ~10Ω on-resistance
* Open: disconnects (modeled as switch opening at t=1us)
* Simplified: current source pulling down, then opening
*
* SCL: 400kHz clock, 50% duty cycle
V_SCL_DRV SCL_DRV GND PULSE(0 1 0 2ns 2ns 1.25us 2.5us)
R_SCL_OPEN SCL SCL_DRV 10    ; pull-down when high, else open

* SDA: held low (START), then released at t=500ns
V_SDA_DRV SDA_DRV GND PULSE(1 0 0 2ns 2ns 500ns 10us)
R_SDA_PULL SDA SDA_DRV 10

.tran 2ns 5us

.measure tran RISE_SDA trise V(SDA) val=0.3*3.3 val2=0.7*3.3

.control
run
plot V(SDA) V(SCL) title 'I2C SDA/SCL timing (4.7k pullup, 90pF bus)'
print RISE_SDA
quit
.endc

.end
