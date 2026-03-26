* Kill_LIFE MEMS Microphone Bias Circuit
* Mic: ICS-43434 digital MEMS (I2S output, no analog bias needed)
* I2S pins: SCK=GPIO15, WS=GPIO2, SD=GPIO39
*
* Note: ICS-43434 is a digital I2S mic with internal ADC.
* This netlist models the DECOUPLING of VDD_MIC (3.3V) and
* the SDO pulldown resistor behavior.
*
* ICS-43434 specs:
*   - VDD: 1.71V–3.6V (3.3V typical)
*   - Current: 0.9mA active, 0.5mA idle
*   - SDO output: 3.3V CMOS, 10pF load
*   - Frequency response: 50Hz–20kHz ±1dB

* --- Supply ---
V_VDD VDD GND DC 3.3V

* --- VDD decoupling (per datasheet Fig. 4) ---
C_VDD_100N VDD GND 100nF
C_VDD_1U VDD GND 1uF

* --- SDO pulldown resistor ---
* SD pin has 1MΩ pulldown to select L/R channel
* Left channel: SD pulled LOW
R_SD_PULLDOWN SD_PIN GND 1MEG

* --- SDO line model ---
* 5cm PCB trace at 3.3V CMOS, 10pF load + 10pF cable
R_TRACE_SD SD_PIN SD_ESP 33
C_TRACE_SD SD_ESP GND 10pF
C_LOAD_SD SD_ESP GND 10pF

* --- SCK/WS drive (ESP32-S3 GPIO output, 50 ohm drive strength) ---
V_SCK SCK_PIN GND PULSE(0 3.3V 0 1ns 1ns 31.25ns 62.5ns)  ; 16MHz SCK
R_SCK_DRIVE SCK_PIN SCK_MIC 50
C_SCK_MIC SCK_MIC GND 5pF

* --- Transient: one I2S clock cycle ---
.tran 100ps 500ns

.control
run
plot V(SCK_MIC) V(SD_ESP) title 'I2S SCK and SD timing'
print V(VDD)
quit
.endc

.end
