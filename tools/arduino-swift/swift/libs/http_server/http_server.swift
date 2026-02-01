//
//  http_server.swift
//  ArduinoSwift - Minimal HTTP Server (UNO R4 WiFi)
//
//  A tiny HTTP/1.1 server designed for Embedded Swift environments.
//  It runs cooperatively (tick-based) and integrates with ArduinoRuntime
//  via ArduinoTickable.
//
//  Design goals:
//  - No Foundation dependency (no CharacterSet, split, trimming, JSONSerialization, etc.)
//  - Avoid Unicode normalization-heavy APIs to keep the embedded link clean
//  - Parse HTTP requests using raw bytes (ASCII/UTF-8) with small fixed limits
//  - Support basic routing for GET and POST
//  - Provide a small JSON encoder without Dictionaries (ordered tuples instead)
//
//  How it works:
//  - The C++ side exposes a small C-ABI for an underlying WiFi server/client.
//  - This Swift layer polls for an available client and reads bytes into a buffer.
//  - It detects the end of headers (\r\n\r\n), parses the request line + headers,
//    optionally reads Content-Length bytes, routes the request, writes a response,
//    and closes the connection.
//
//  Limitations:
//  - One request per connection, Connection: close
//  - Body is read only via Content-Length (no chunked transfer encoding)
//  - Minimal parsing, intended for LAN/dev usage on microcontrollers
//
//  JSON notes:
//  - JSON numbers: int (I32) and float (F32)
//  - Parser supports: object/array/string/number/bool/null + basic escapes
//  - Not supported: \uXXXX, scientific notation (1e-3), NaN/Inf in encoder
//