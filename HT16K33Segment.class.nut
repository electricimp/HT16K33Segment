class HT16K33Segment {
    // Hardware driver for Adafruit 0.56-inch 4-digit, 7-segment LED display
    // based on the Holtek HT16K33 controller.
    // The LED communicates over any imp I2C bus.

    // Written by Tony Smith (smittytone) 2014-16
    // Copyright Electric Imp, Inc. 2014-2016.
    // https://electricimp.com/
    // Licence: MIT

    // HT16K33 registers and HT16K33-specific constants
    static HT16K33_REGISTER_DISPLAY_ON  = "\x81";
    static HT16K33_REGISTER_DISPLAY_OFF = "\x80";
    static HT16K33_REGISTER_SYSTEM_ON   = "\x21";
    static HT16K33_REGISTER_SYSTEM_OFF  = "\x20";
    static HT16K33_DISPLAY_ADDRESS      = "\x00";
    static HT16K33_I2C_ADDRESS          = 0x70;
    static HT16K33_BLANK_CHAR           = 16;
    static HT16K33_MINUS_CHAR           = 17;
    static HT16K33_CHAR_COUNT           = 17;

    static version = [1,2,0];

    // Class properties; those defined in the Constructor must be null
    _buffer = null;
    _digits = null;
    _led = null;
    _ledAddress = 0;
    _debug = false;

    constructor(i2cBus = null, i2cAddress = 0x70, debug = false) {
        // Parameters:
        //   1. Whichever CONFIGURED imp I2C bus is to be used for the HT16K33
        //   2. The HT16K33's I2C address (default: 0x70)
        //   3. Boolean to request extra debugging information in the log

        if (i2cBus == null || i2cAddress == 0) {
            server.error("HT16K33Segment() requires a non-null imp I2C bus object and a non-zero I2C address");
            return null;
        }

        _led = i2cBus;
        _ledAddress = i2cAddress << 1;
        _debug = debug;

        // _buffer stores the character matrix values for each row of the display,
        // Including the center colon character
        //
        //     0    1   2   3    4
        //    [ ]  [ ]     [ ]  [ ]
        //     -    -   .   -    -
        //    [ ]  [ ]  .  [ ]  [ ]

        _buffer = [0x00, 0x00, 0x00, 0x00, 0x00];

        // _digits store character matrices for 0-9, A-F, blank and minus
        _digits = [
            0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F,  // 0-9
            0x5F, 0x7C, 0x58, 0x5E, 0x7B, 0x71,                          // A-F
            0x00, 0x40                                                   // Space, minus sign
        ];

        init();
    }

    function init(clearChar = 16, brightness = 15, showColon = false) {
        // Parameters:
        //   1. Integer index for the _digits[] character matrix to zero the display to
        //   2. Integer value for the display brightness, between 0 and 15
        //   3. Boolean value - should the colon (_digits[2]) be shown?
        // Returns:
        //    Nothing

        // Power up the display
        powerUp();

        // Set the brightness, which power cyles the dispay
        // Note: setBrightness() verifies the brightness value
        setBrightness(brightness);

        // Clear the screen to the chosen character
        // Note: clearBuffer() verifies the clearChar value
        clearBuffer();
    }

    function clearBuffer(clearChar = 16) {
        // Fills the buffer with a blank character, or the _digits[] character matrix whose index is provided
        // Returns:
        //    the instance (this)

        if (clearChar < 0 || clearChar > HT16K33_CHAR_COUNT) {
            clearChar = HT16K33_BLANK_CHAR;
            server.error("HT16K33Segment.clearBuffer() passed out-of-range character value (0-16)");
        }

        // Put the clearCharacter into the buffer except row 2 (colon row)
        _buffer[0] = _digits[clearChar];
        _buffer[1] = _digits[clearChar];
        _buffer[3] = _digits[clearChar];
        _buffer[4] = _digits[clearChar];
        return this;
    }

    function writeChar(rowNum, charVal, hasDot = false) {
        // Puts the input character matrix (an 8-bit integer) into the specified row,
        // adding a decimal point if required. Character matrix value is calculated by
        // setting the bit(s) representing the segment(s) you want illuminated.
        // Bit-to-segment mapping runs clockwise from the top around the outside of the
        // matrix; the inner segment is bit 6:
        //
        //         0
        //         _
        //     5 |   | 1
        //       |   |
        //         - <----- 6
        //     4 |   | 2
        //       | _ |
        //         3
        //
        // Bit 7 is the period, but this is set with parameter 3
        // Parameters:
        //   1. The digit to be written to (0, 1, 3 or 4)
        //   2. The integer index valur of the character required (0 - 17)
        //   3. Boolean indicating whether the digit is followed by a period
        // Returns:
        //    the instance (this)

        if (charVal < 0 || charVal > 255) {
            server.error("HT16K33Segment.writeChar() character out of range (0-255)");
            return this;
        }

        if (rowNum < 0 || rowNum > 4) {
            server.error("HT16K33Segment.writeChar() chosen row out of range (0-4)");
            return this;
        }

        _buffer[rowNum] = hasDot ? (charVal | 0x80) : charVal;
        if (_debug) server.log(format("Row %d set to character defined by 0x%02x %s", rowNum, charVal, (hasDot ? "with period" : "without period")));
        return this;
    }

    function writeNumber(rowNum, intVal, hasDot = false) {
        // Puts the number - ie. index of _digits[] - into the specified row,
        // adding a decimal point if required
        // Parameters:
        //   1. The digit to be written to (0, 1, 3 or 4)
        //   2. The integer index valur of the character required (0 - 17)
        //   3. Boolean indicating whether the digit is followed by a period
        // Returns:
        //    the instance (this)

        if (rowNum < 0 || rowNum > 4) {
            server.error("HT16K33Segment.writeNumber() chosen row out of range (0-4)");
            return this;
        }

        if (intVal < 0 || intVal > 17) {
            server.error("HT16K33Segment.writeNumber() numeric character out of range (0x00-0x0F): " + intVal);
            return this;
        }

        _buffer[rowNum] = hasDot ? (_digits[intVal] | 0x80) : _digits[intVal];
        if (_debug) server.log(format("Row %d set to integer %d %s", rowNum, intVal, (hasDot ? "with period" : "without period")));
        return this;
    }

    function clearDisplay() {
        // Convenience method to clear the display
        clearBuffer().setColon(false).updateDisplay();
    }

    function updateDisplay() {
        // Converts the row-indexed buffer[] values into a single, combined
        // string and writes it to the HT16K33 via I2C
        local dataString = HT16K33_DISPLAY_ADDRESS;

        for (local i = 0 ; i < 5 ; ++i) {
            dataString = dataString + _buffer[i].tochar() + "\x00";
        }

        // Write the combined datastring to I2C
        _led.write(_ledAddress, dataString);
    }

    function setColon(set) {
        // Shows or hides the colon row (display row 2)
        // Parameter:
        //   1. Boolean indicating whether colon is shown (true) or hidden (false)
        // Returns:
        //    the instance (this)

        _buffer[2] = set ? 0xFF : 0x00;
        if (_debug) server.log(format("Colon set %s", (set ? "on" : "off")));
        return this;
    }

    function setBrightness(brightness = 15) {
        // Parameters:
        //    1. Integer brightness value: 0 (min. but not off) to 15 (max) Default: 15
        // Returns:
        //    Nothing

        if (brightness > 15) {
            brightness = 15;
            if (_debug) server.error("HT16K33Segment.setBrightness() brightness out of range (0-15)");
        }

        if (brightness < 0) {
            brightness = 0;
            if (_debug) server.error("HT16K33Segment.setBrightness() brightness out of range (0-15)");
        }

        brightness = brightness + 224;
        if (_debug) server.log("Brightness set to " + brightness);

        // Write the new brightness value to the HT16K33
        _led.write(_ledAddress, brightness.tochar() + "\x00")
    }

    function setDisplayFlash(flashInHertz = 0) {
        // Parameters:
        //    1. Flash rate in Herz. Must be 0.5, 1 or 2 for a flash, or 0 for no flash
        // Returns:
        //    Nothing

        local values = [0, 2, 1, 0.5];
        local match = -1;
        foreach (i, value in values) {
            if (value == flashInHertz) {
                match = i;
                break;
            }
        }

        if (match == -1) {
            server.error("HT16K33Segment.setDisplayBlink() passed an invalid blink frequency");
            return null;
        }

        match = 0x81 + (match << 1);
        _led.write(_ledAddress, match.tochar() + "\x00");
        if (_debug) server.log(format("Display flash set to %d Hz", ((match - 0x81) >> 1)));
    }

    function powerDown() {
        if (_debug) server.log("Powering HT16K33Segment display down");
        _led.write(_ledAddress, HT16K33_REGISTER_DISPLAY_OFF);
        _led.write(_ledAddress, HT16K33_REGISTER_SYSTEM_OFF);
    }

    function powerUp() {
        if (_debug) server.log("Powering HT16K33Segment display up");
        _led.write(_ledAddress, HT16K33_REGISTER_SYSTEM_ON);
        _led.write(_ledAddress, HT16K33_REGISTER_DISPLAY_ON);
    }
}
