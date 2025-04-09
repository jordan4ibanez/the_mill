module game.player;

import controls.keyboard;
import game.map;
import graphics.colors;
import graphics.render;
import graphics.texture;
import math.rect;
import math.vec2d;
import math.vec2i;
import raylib : DEG2RAD, PI, RAD2DEG;
import std.bitmanip;
import std.conv;
import std.math.algebraic : abs;
import std.math.rounding;
import std.math.traits : sgn;
import std.math.trigonometry;
import std.stdio;
import utility.collision_functions;
import utility.delta;
import utility.drawing_functions;

private struct AnimationState {
    mixin(bitfields!(
            ubyte, "state", 2,
            ubyte, "direction", 3,
            ubyte, "frame", 3));
}

static final const class Player {
static:
private:

    Vec2d size = Vec2d(1, 1);
    Vec2d position = Vec2d(32, 32);
    Vec2d velocity = Vec2d(0, 0);
    Vec2i inChunk = Vec2i(int.max, int.max);
    bool firstGen = true;
    bool moving = false;
    // states:
    // 0 standing
    // 1 walking
    // 2 mining
    ubyte animationState = 1;
    ubyte directionFrame = 6;
    ubyte animationFrame = 0;
    double animationTimer = 0;

public: //* BEGIN PUBLIC API.

    Vec2d getSize() {
        return size;
    }

    Vec2d getPosition() {
        return position;
    }

    double getWidth() {
        return size.y;
    }

    Vec2d getVelocity() {
        return velocity;
    }

    void setPosition(Vec2d newPosition) {
        position = newPosition;
    }

    void setVelocity(Vec2d newVelocity) {
        velocity = newVelocity;
    }

    Rect getRectangle() {
        Vec2d centeredPosition = centerCollisionbox(position, size);
        return Rect(centeredPosition.x, centeredPosition.y, size.x, size.y);
    }

    /// Get if the player is moving.
    bool isMoving() {
        return moving;
    }

    void draw() {

        double delta = Delta.getDelta();

        animationTimer += delta;

        static immutable double _frameGoalWalking = 0.1;
        static immutable double _frameGoalStanding = 0.25;

        double frameGoal = 0;

        // Walking is animated slightly faster.
        if (animationState == 1) {
            frameGoal = _frameGoalWalking;
        } else { // Everything else is slightly slower.
            frameGoal = _frameGoalStanding;
        }

        if (animationTimer >= frameGoal) {
            animationTimer -= frameGoal;

            animationFrame++;

            // Walking has 8 frames.
            if (animationState == 1) {
                if (animationFrame >= 8) {
                    animationFrame = 0;
                }
            } else { // Everything else (for now) has 4.
                if (animationFrame >= 4) {
                    animationFrame = 0;
                }
            }
        }

        Render.rectangleLines(centerCollisionbox(position, size), size, Colors.WHITE);

        Vec2d adjustedPosition = centerCollisionbox(position, Vec2d(3, 3));
        adjustedPosition.y += 1.0;

        // This is some next level debugging horror right here lmao.
        string animationName;

        final switch (animationState) {
        case 0:
            animationName = "standing";
            break;
        case 1:
            animationName = "walking";
            break;
        case 2:
            animationName = "mining";
            break;
        }

        const string textureName = "player_" ~ animationName ~ "_direction_" ~ to!string(
            directionFrame) ~ "_frame_" ~ to!string(animationFrame) ~ ".png";

        TextureHandler.drawTexture(textureName, adjustedPosition, Rect(0, 0, 88, 88), Vec2d(3, 3));

    }

    void setAnimationState(ubyte newState) {
        // Walking has 8 frames.
        // Everything else (for now) has 4.
        // So we must catch that.
        if (newState != 1) {
            if (animationFrame >= 4) {
                animationFrame = 0;
            }
        }

        animationState = newState;
    }

    void move() {
        double delta = Delta.getDelta();

        // Todo: Make this API element later.
        const double acceleration = 40;
        const double deceleration = 50;
        const double topSpeed = 7;

        // writeln(velocity.x);

        moving = false;

        int xInput = 0;
        int yInput = 0;

        //? Controls first.
        if (Keyboard.isDown(KeyboardKey.KEY_D)) {
            moving = true;
            xInput = 1;
            velocity.x = topSpeed;
        } else if (Keyboard.isDown(KeyboardKey.KEY_A)) {
            moving = true;
            xInput = -1;
            velocity.x = -topSpeed;
        } else {
            velocity.x = 0;
        }
        if (Keyboard.isDown(KeyboardKey.KEY_W)) {
            moving = true;
            yInput = 1;
            velocity.y = topSpeed;
        } else if (Keyboard.isDown(KeyboardKey.KEY_S)) {
            moving = true;
            yInput = -1;
            velocity.y = -topSpeed;
        } else {
            velocity.y = 0;
        }

        // Speed limiter. 
        if (vec2dLength(velocity) > topSpeed) {
            velocity = vec2dMultiply(vec2dNormalize(velocity), Vec2d(topSpeed, topSpeed));
        }

        //? Then apply Y axis.
        position.y += velocity.y * delta;

        //? Finally apply X axis.
        position.x += velocity.x * delta;

        //! Animation components.
        setAnimationState(moving ? 1 : 0);
        // todo: figure out a way to bitshift into this because this is hilarious.
        if (moving) {
            if (xInput == -1 && yInput == 0) {
                directionFrame = 0;
            } else if (xInput == -1 && yInput == 1) {
                directionFrame = 1;
            } else if (xInput == 0 && yInput == 1) {
                directionFrame = 2;
            } else if (xInput == 1 && yInput == 1) {
                directionFrame = 3;
            } else if (xInput == 1 && yInput == 0) {
                directionFrame = 4;
            } else if (xInput == 1 && yInput == -1) {
                directionFrame = 5;
            } else if (xInput == 0 && yInput == -1) {
                directionFrame = 6;
            } else if (xInput == -1 && yInput == -1) {
                directionFrame = 7;
            }

        }

        //! End animation components.

        // Map.collideEntityToWorld(position, size, velocity, CollisionAxis.X);

        // if (velocity.x == 0 && velocity.y == 0) {
        //     moving = false;
        // }

        Vec2i oldChunk = inChunk;
        Vec2i newChunk = Map.calculateChunkAtWorldPosition(position);

        if (oldChunk != newChunk) {
            inChunk = newChunk;
            Map.worldLoad(inChunk);
        }
    }

    Vec2i inWhichChunk() {
        return inChunk;
    }

private: //* BEGIN INTERNAL API.

}
