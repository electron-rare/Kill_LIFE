/* Native build stub — compile guard for host-side toolchain validation only.
   Actual firmware runs on ESP32 targets (esp32s3_arduino, esp32_arduino). */
#ifdef UNIT_TEST
int main() { return 0; }
#endif
