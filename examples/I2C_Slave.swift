// App.swift — Due as I2C SLAVE (ASCII-only)
// Address: 0x12

@_silgen_name("arduino_swift_main")
public func arduino_swift_main() {
    print("Due SLAVE boot (addr 0x12)\n")

    let led = PIN.builtin
    led.off()

    // Prebuilt replies (ASCII only)
    var reply = asciiPacket("Idle")

    let dev = I2C.SlaveDevice(address: 0x12)

    dev.onReceive = { pkt in
        let b = pkt.bytes

        print("[I2C RX] bytes=")
        I2C.Print.hexBytes(b)
        Serial.print("\n")

        if asciiEquals(b, asciiBytes("LED_ON")) {
            led.on()
            reply = asciiPacket("Acendi o Led")
            print("-> LED ON\n")
        } else if asciiEquals(b, asciiBytes("LED_OFF")) {
            led.off()
            reply = asciiPacket("Apaguei o Led")
            print("-> LED OFF\n")
        } else {
            reply = asciiPacket("Cmd invalido")
            print("-> INVALID CMD\n")
        }
    }

    dev.onRequest = {
        reply
    }

    ArduinoRuntime.add(dev)
    ArduinoRuntime.keepAlive()
}

//Arduino IDE - Master

// #include <Wire.h>

// static const uint8_t DUE_ADDR = 0x12;   // endereço do Due como SLAVE

// static const uint8_t BTN_ON  = 5;       // botão no pino 5
// static const uint8_t BTN_OFF = 6;       // botão no pino 6

// static bool lastOn  = true;
// static bool lastOff = true;

// static void sendCmdAndReadReply(const char* cmd) {
//   // --- SEND ---
//   Wire.beginTransmission(DUE_ADDR);
//   Wire.write((const uint8_t*)cmd, strlen(cmd));
//   uint8_t err = Wire.endTransmission(true);

//   Serial.print("[TX] ");
//   Serial.print(cmd);
//   Serial.print(" endTx=");
//   Serial.println(err);

//   // --- READ REPLY (optional but nice) ---
//   delay(5); // pequeno respiro

//   const uint8_t max = 32;
//   uint8_t got = Wire.requestFrom((int)DUE_ADDR, (int)max, (int)true);

//   Serial.print("[RX] got=");
//   Serial.print(got);
//   Serial.print(" msg=\"");

//   while (Wire.available()) {
//     char c = (char)Wire.read();
//     Serial.print(c);
//   }
//   Serial.println("\"");
// }

// void setup() {
//   Serial.begin(115200);
//   while (!Serial) { delay(10); }

//   Serial.println("R4 MASTER boot");

//   Wire.begin();              // Master
//   Wire.setClock(100000);

//   pinMode(BTN_ON, INPUT_PULLUP);
//   pinMode(BTN_OFF, INPUT_PULLUP);

//   Serial.println("Buttons: D5=ON, D6=OFF (pullup)");
//   Serial.println("Ready.");
// }

// void loop() {
//   bool onNow  = (digitalRead(BTN_ON)  == LOW);
//   bool offNow = (digitalRead(BTN_OFF) == LOW);

//   // borda de descida (pressionou)
//   if (lastOn && onNow) {
//     sendCmdAndReadReply("LED_ON");
//   }
//   if (lastOff && offNow) {
//     sendCmdAndReadReply("LED_OFF");
//   }

//   lastOn  = onNow;
//   lastOff = offNow;

//   delay(10); // debounce simples
// }