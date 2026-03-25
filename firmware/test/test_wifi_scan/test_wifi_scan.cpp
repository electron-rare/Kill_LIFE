#include <unity.h>
#include <string>
#include "../src/wifi_scanner.h"

void test_serialize_basic(void) {
    String result = serialize_network("MyNet", -65, 6, 3);
    TEST_ASSERT_EQUAL_STRING(
        "{\"ssid\":\"MyNet\",\"rssi\":-65,\"channel\":6,\"auth\":3}",
        result.c_str()
    );
}

void test_serialize_empty_ssid(void) {
    String result = serialize_network("", -80, 1, 0);
    TEST_ASSERT_EQUAL_STRING(
        "{\"ssid\":\"\",\"rssi\":-80,\"channel\":1,\"auth\":0}",
        result.c_str()
    );
}

void test_serialize_escaped_quotes(void) {
    String result = serialize_network("Net\"Work", -70, 11, 2);
    TEST_ASSERT_EQUAL_STRING(
        "{\"ssid\":\"Net\\\"Work\",\"rssi\":-70,\"channel\":11,\"auth\":2}",
        result.c_str()
    );
}

void test_serialize_escaped_backslash(void) {
    String result = serialize_network("Net\\Work", -55, 6, 3);
    TEST_ASSERT_EQUAL_STRING(
        "{\"ssid\":\"Net\\\\Work\",\"rssi\":-55,\"channel\":6,\"auth\":3}",
        result.c_str()
    );
}

void test_escape_json_string_plain(void) {
    String result = escape_json_string("HelloWorld");
    TEST_ASSERT_EQUAL_STRING("HelloWorld", result.c_str());
}

void test_escape_json_string_special_chars(void) {
    String result = escape_json_string("a\"b\\c");
    TEST_ASSERT_EQUAL_STRING("a\\\"b\\\\c", result.c_str());
}

int main(int, char**) {
    UNITY_BEGIN();
    RUN_TEST(test_serialize_basic);
    RUN_TEST(test_serialize_empty_ssid);
    RUN_TEST(test_serialize_escaped_quotes);
    RUN_TEST(test_serialize_escaped_backslash);
    RUN_TEST(test_escape_json_string_plain);
    RUN_TEST(test_escape_json_string_special_chars);
    return UNITY_END();
}
