module gui.gui;

import graphics.colors;
import gui.font;
import math.vec2d;
import math.vec2i;
import std.stdio;

/*
*
*   CONTROLS PROVIDED:
*     # Container/separators Controls
*       - WindowBox     --> StatusBar, Panel
*       - GroupBox      --> Line
*       - Line
*       - Panel         --> StatusBar
*       - ScrollPanel   --> StatusBar
*       - TabBar        --> Button
*
*     # Basic Controls
*       - Label
*       - LabelButton   --> Label
*       - Button
*       - Toggle
*       - ToggleGroup   --> Toggle
*       - ToggleSlider
*       - CheckBox
*       - ComboBox
*       - DropdownBox
*       - TextBox
*       - ValueBox      --> TextBox
*       - Spinner       --> Button, ValueBox
*       - Slider
*       - SliderBar     --> Slider
*       - ProgressBar
*       - StatusBar
*       - DummyRec
*       - Grid
*
*     # Advance Controls
*       - ListView
*       - ColorPicker   --> ColorPanel, ColorBarHue
*       - MessageBox    --> Window, Label, Button
*       - TextInputBox  --> Window, Label, TextBox, Button
*/

class Element {

}

// This is the basis of any GUI component, the container.
class Container {
    bool visible = true;

    // What this container is called.
    string containerName = null;

    // Position is top left of container.
    Vec2i position;
    Vec2i size;

    // General solid colors.

    // The color of the work area.
    Color workAreaColor = Colors.GRAY;
    // The border color of the window. (All border components.)
    Color borderColor = Colors.BLACK;
    // The status bar background color.
    Color statusBarColor = Colors.BLUE;

    // General text colors.

    // The text below the status bar.
    Color workAreaTextColor = Colors.BLACK;
    // The status bar text color.
    Color statusBarTextColor = Colors.WHITE;
}

static final const class GUI {
static:
private:

    // We standardize the GUI with 1080p.
    const Vec2d standardSize = Vec2d(1920.0, 1080.0);
    double currentGUIScale = 1.0;

    Container[string] interfaces;

public: //* BEGIN PUBLIC API.

    void drawVisible() {
        foreach (key, value; interfaces) {
            writeln(key, " ", value, " ", value.containerName);

        }
    }

    void debugTest() {

        Container testContainer = new Container();

        testContainer.containerName = "Test container";

        interfaces["testMenu"] = testContainer;

    }

    double getGUIScale() {
        return currentGUIScale;
    }

    void initialize() {
        FontHandler.initialize();
        debugTest();
    }

    void terminate() {
        FontHandler.terminate();
    }

    void __update(Vec2d newWindowSize) {
        // Find out which GUI scale is smaller so things can be scaled around it.

        Vec2d scales = Vec2d(newWindowSize.x / standardSize.x, newWindowSize.y / standardSize.y);

        if (scales.x >= scales.y) {
            currentGUIScale = scales.y;
        } else {
            currentGUIScale = scales.x;
        }

        FontHandler.__update();
    }

private: //* BEGIN INTERNAL API.

}
