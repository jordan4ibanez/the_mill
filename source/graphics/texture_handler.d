module graphics.texture_handler;

public import fast_pack : TexturePoints;
import core.memory;
import fast_pack;
import math.rect;
import math.vec2d;
import raylib;
import std.container;
import std.file;
import std.path;
import std.regex;
import std.stdio;
import std.string;

static final const class TextureHandler {
static:
private:

    TexturePacker!string database = TexturePacker!string(1);
    Texture2D atlas;
    TexturePoints!Vec2d[string] texturePointDatabase;

    //! NEVER USE THESE IN YOUR MODS.
    TexturePoints!Vec2d* ultraFastTexturePointAccess;
    ulong[string] texturePointAccessReverseLookup;

public: //* BEGIN PUBLIC API.

    void initialize() {

        foreach (string thisFilePathString; dirEntries("textures", "*.png", SpanMode.depth)) {
            loadTexture(thisFilePathString);
        }

        database.finalize("atlas.png");

        atlas = LoadTexture(toStringz("atlas.png"));

        database.extractTexturePoints(texturePointDatabase);

        // Begin ultra fast lookup for map mesh generation.

        ultraFastTexturePointAccess = cast(TexturePoints!Vec2d*) GC.malloc(
            TexturePoints!Vec2d.sizeof * texturePointDatabase.length);

        ulong index = 0;
        foreach (key, value; texturePointDatabase) {
            texturePointAccessReverseLookup[key] = index;

            ultraFastTexturePointAccess[index] = value;
            index++;
        }
    }

    void drawTexture(string textureName, Vec2d position, Rect sourceOnTexture, Vec2d size, Vec2d origin = Vec2d(0, 0),
        double rotation = 0) {

        Vec2d flippedPosition = Vec2d(position.x, -position.y);

        struct OutputRect {
            int x = 0;
            int y = 0;
            int w = 0;
            int h = 0;
        }

        OutputRect rawInput;
        database.getRectangleIntegral(textureName, rawInput);

        Rect source = Rect();
        source.x = rawInput.x + cast(int) sourceOnTexture.x;
        source.y = rawInput.y + cast(int) sourceOnTexture.y;
        source.width = sourceOnTexture.width;
        source.height = sourceOnTexture.height;

        Rect dest = Rect(
            flippedPosition.x,
            flippedPosition.y,
            size.x,
            size.y
        );

        DrawTexturePro(atlas, source.toRaylib(), dest.toRaylib(), origin.toRaylib(), rotation, Colors
                .WHITE);
    }

    bool hasTexture(string name) {
        return database.contains(name);
    }

    TexturePoints!Vec2d getTexturePoints(string textureName) {
        TexturePoints!Vec2d* theseTexturePoints = textureName in texturePointDatabase;
        if (theseTexturePoints is null) {
            throw new Error("missing texture");
        }
        return *theseTexturePoints;
    }

    void loadTexture(string location) {

        // Extract the file name from the location.
        string fileName = () {
            string[] items = location.split("/");
            int len = cast(int) items.length;
            if (len <= 1) {
                throw new Error("[TextureManager]: Texture must not be in root directory.");
            }
            string outputFileName = items[len - 1];
            if (!outputFileName.endsWith(".png")) {
                throw new Error("[TextureManager]: Not a .png");
            }
            return outputFileName;
        }();

        database.pack(fileName, location);
    }

    Texture2D getAtlas() {
        return atlas;
    }

    /// If you use this in your mods, you're going to have an extremely bad time.
    TexturePoints!Vec2d* getTexturePointsPointer(ulong index) {
        return ultraFastTexturePointAccess + index;
    }

    ulong lookupTexturePointsIndex(string name) {
        ulong* thisIndex = name in texturePointAccessReverseLookup;
        if (thisIndex is null) {
            throw new Error("Texture " ~ name ~ " does not exist");
        }
        return *thisIndex;
    }

    void terminate() {
        UnloadTexture(atlas);
    }

private: //* BEGIN INTERNAL API.
}
