* Kill_LIFE I2S Audio Output Stage
* DAC: PCM5101A (Waveshare ESP32-S3-LCD-1.85)
* I2S pins: BCK=GPIO48, WS=GPIO38, DOUT=GPIO47
* Output: Stereo 3.5mm jack, 16Ω headphone load
*
* PCM5101A key specs:
*   - Output voltage swing: 2.1Vrms (6Vpp) into open load
*   - Output impedance: ~100Ω internal
*   - THD+N: -93dBc @ 1kHz
*   - Frequency response: 20Hz–20kHz ±0.5dB
*
* This netlist models the analog output path:
*   PCM5101A out → RC low-pass (brick-wall optional) → 3.5mm jack → headphones

* --- PCM5101A output model (one channel) ---
* Thevenin equivalent: 2.1Vrms sine @ 1kHz, 100Ω source impedance
V_DAC DAC_OUT GND AC 2.97V  ; 2.1Vrms * sqrt(2) = 2.97V peak
R_DAC_OUT DAC_OUT ANA_OUT 100

* --- DC blocking capacitor (typical: 470uF electrolytic) ---
C_BLOCK ANA_OUT JACK_HOT 470uF

* --- Output filter (optional RC anti-alias / EMI) ---
* 47Ω + 1nF → fc = 3.4MHz (above audio band, attenuates RF)
R_FILTER JACK_HOT FILTERED 47
C_FILTER FILTERED GND 1nF

* --- Headphone load (16Ω) ---
R_HP FILTERED GND 16

* --- Analysis: frequency sweep 20Hz–100kHz ---
.ac dec 100 20 100k

.measure ac F_3dB when vdb(FILTERED)=vdb(FILTERED,f=1000)-3

.control
run
plot db(V(FILTERED)/V(DAC_OUT)) title 'PCM5101A Output Frequency Response'
print V(FILTERED,f=1000)
quit
.endc

.end
