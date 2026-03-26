* Kill_LIFE ESP32-S3 Power Supply Decoupling
* Board: Waveshare ESP32-S3-LCD-1.85
* Supply: USB 5V → AMS1117-3.3 LDO → 3.3V rail
* Purpose: Verify decoupling cap effectiveness at 80 MHz core clock
*
* References:
*   - ESP32-S3 TRM section 4.1 (Power Supply)
*   - AMS1117-3.3 datasheet
*   - ESP32-S3 HW Design Guidelines: 100nF + 10uF per VDD pin

* --- Power Source ---
V_USB VCC_5V GND DC 5V

* --- LDO AMS1117-3.3 (simplified VCCS model) ---
* Output impedance ~0.3Ω at DC, bandwidth ~50kHz
R_LDO_OUT VCC_5V V33_RAIL 0.3
C_LDO_OUT V33_RAIL GND 10uF

* --- PCB trace inductance (5cm trace, ~10nH) ---
L_TRACE V33_RAIL V33_LOCAL 10nH
R_TRACE V33_LOCAL GND 0.01   ; trace resistance (damping)

* --- Decoupling capacitors at ESP32-S3 VDD pins ---
* Standard BOM: 100nF X5R 0603 + 10uF X5R 0805 per pair
C_DEC1 V33_LOCAL GND 100nF
C_DEC2 V33_LOCAL GND 10uF
C_DEC3 V33_LOCAL GND 100nF  ; second VDD pair
C_DEC4 V33_LOCAL GND 10uF

* --- ESP32-S3 digital load model ---
* 80 MHz clock switching: ~50mA peak, 100ps rise/fall (simplified as current pulse)
* Static current: ~80mA typical active
I_ESP32_STATIC V33_LOCAL GND DC 80mA
* Switching noise source (20mA @ 80MHz harmonic)
I_ESP32_SWITCH V33_LOCAL GND AC 20mA

* --- Analysis ---
.ac dec 100 1k 1G

.control
run
print V(V33_LOCAL)
plot db(V(V33_LOCAL)) title 'VDD Rail Impedance vs Frequency'
quit
.endc

.end
