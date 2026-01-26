// App.swift — I2C Master with Buttons

@_silgen_name("arduino_swift_main")
public func arduino_swift_main() {
    Serial.begin(115200)
    Serial.print("Due Master boot\n")

    let i2c = I2C.Bus(clockHz: 100_000)

    // Receive responses from R4
    i2c.onReceive { from, packet in
        Serial.print("RX from 0x")
        Serial.printHexBytes(packet.bytes)
        Serial.print(": ")

        if let s = packet.asUTF8String() {
            Serial.print(s)
        } else {
            Serial.printHexBytes(packet.bytes)
        }
        Serial.print("\n")
    }

    // Optional error logging
    i2c.onError { addr, status in
        Serial.print("I2C error to 0x")
        Serial.printHex2(addr)
        Serial.print(" status=")
        Serial.print(status.name)
        Serial.print("\n")
    }

    // Button on pin 5 -> LED ON
    let btnOn = Button(5, onPress: {
        Serial.print("Button 5 pressed -> LED ON\n")
        _ = i2c.send(to: 0x12, "LED_ON")
    })

    // Button on pin 6 -> LED OFF
    let btnOff = Button(6, onPress: {
        Serial.print("Button 6 pressed -> LED OFF\n")
        _ = i2c.send(to: 0x12, "LED_OFF")
    })

    // Poll slave every 100ms to get response text
    let poller = i2c.poller(from: 0x12, count: 32, everyMs: 100)

    ArduinoRuntime.add(btnOn)
    ArduinoRuntime.add(btnOff)
    ArduinoRuntime.add(poller)

    ArduinoRuntime.keepAlive()
}


// Arduino Slave Sketch

// #include <Wire.h>

// static const uint8_t I2C_ADDR = 0x12;
// static const uint8_t LED_PIN = LED_BUILTIN;

// static char lastResponse[32] = "Idle";

// void onReceiveHandler(int count) {
//   char buf[16];
//   uint8_t i = 0;

//   while (Wire.available() && i < sizeof(buf) - 1) {
//     buf[i++] = (char)Wire.read();
//   }
//   buf[i] = '\0';

//   if (strcmp(buf, "LED_ON") == 0) {
//     digitalWrite(LED_PIN, HIGH);
//     strcpy(lastResponse, "Acendi o Led");
//   }
//   else if (strcmp(buf, "LED_OFF") == 0) {
//     digitalWrite(LED_PIN, LOW);
//     strcpy(lastResponse, "Apaguei o Led");
//   }
// }

// void onRequestHandler() {
//   Wire.write((const uint8_t*)lastResponse, strlen(lastResponse));
// }

// void setup() {
//   pinMode(LED_PIN, OUTPUT);
//   digitalWrite(LED_PIN, LOW);

//   Serial.begin(115200);
//   while (!Serial) {}

//   Serial.println("R4 I2C SLAVE boot");
//   Serial.print("Address: 0x");
//   Serial.println(I2C_ADDR, HEX);

//   Wire.begin(I2C_ADDR);
//   Wire.onReceive(onReceiveHandler);
//   Wire.onRequest(onRequestHandler);

//   Serial.println("Ready.");
// }

// void loop() {
//   // nada aqui, tudo é por I2C
// }