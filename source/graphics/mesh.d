module graphics.mesh;

public import raylib;
import graphics.shader;
import graphics.texture_handler;
import math.vec2d;
import std.conv;
import std.stdio;
import std.string;

// In debug mode, this is slower.
// In release mode, it consistently makes render time immeasurable.
void fastMatrixMultiply(const Matrix* left, const Matrix* right, Matrix* result) {
    result.m0 = left.m0 * right.m0 + left.m1 * right.m4 + left.m2 * right.m8 + left.m3 * right.m12;
    result.m1 = left.m0 * right.m1 + left.m1 * right.m5 + left.m2 * right.m9 + left.m3 * right.m13;
    result.m2 = left.m0 * right.m2 + left.m1 * right.m6 + left.m2 * right.m10 + left.m3 * right.m14;
    result.m3 = left.m0 * right.m3 + left.m1 * right.m7 + left.m2 * right.m11 + left.m3 * right.m15;
    result.m4 = left.m4 * right.m0 + left.m5 * right.m4 + left.m6 * right.m8 + left.m7 * right.m12;
    result.m5 = left.m4 * right.m1 + left.m5 * right.m5 + left.m6 * right.m9 + left.m7 * right.m13;
    result.m6 = left.m4 * right.m2 + left.m5 * right.m6 + left.m6 * right.m10 + left.m7 * right.m14;
    result.m7 = left.m4 * right.m3 + left.m5 * right.m7 + left.m6 * right.m11 + left.m7 * right.m15;
    result.m8 = left.m8 * right.m0 + left.m9 * right.m4 + left.m10 * right.m8 + left.m11 * right
        .m12;
    result.m9 = left.m8 * right.m1 + left.m9 * right.m5 + left.m10 * right.m9 + left.m11 * right
        .m13;
    result.m10 = left.m8 * right.m2 + left.m9 * right.m6 + left.m10 * right.m10 + left.m11 * right
        .m14;
    result.m11 = left.m8 * right.m3 + left.m9 * right.m7 + left.m10 * right.m11 + left.m11 * right
        .m15;
    result.m12 = left.m12 * right.m0 + left.m13 * right.m4 + left.m14 * right.m8 + left.m15 * right
        .m12;
    result.m13 = left.m12 * right.m1 + left.m13 * right.m5 + left.m14 * right.m9 + left.m15 * right
        .m13;
    result.m14 = left.m12 * right.m2 + left.m13 * right.m6 + left.m14 * right.m10 + left.m15 * right
        .m14;
    result.m15 = left.m12 * right.m3 + left.m13 * right.m7 + left.m14 * right.m11 + left.m15 * right
        .m15;
}

static final const class MeshHandler {
static:
private:

    Texture2D textureAtlas;
    Mesh[int] database;

    int nextMeshID = 1;

    int mainShaderID = 0;
    int shaderColorDiffuseUniformLocation = 0;
    int mvpUniformLocation = 0;

    Matrix matView;
    Matrix matProjection;
    Matrix matrixTransform;

public: //* BEGIN PUBLIC API.

    void initialize() {
        textureAtlas = TextureHandler.getAtlas();

        mainShaderID = ShaderHandler.getShaderID("2d");
        shaderColorDiffuseUniformLocation = ShaderHandler.getUniformLocation("2d", "colDiffuse");
        mvpUniformLocation = ShaderHandler.getUniformLocation("2d", "mvp");
    }

    int generate(float* vertices, const ulong verticesLength, float* textureCoordinates) {
        int meshID = nextMeshID;
        nextMeshID++;

        Mesh thisMesh = Mesh();

        thisMesh.vertexCount = cast(int) verticesLength / 2;
        thisMesh.triangleCount = thisMesh.vertexCount / 3;
        thisMesh.vertices = vertices;
        thisMesh.texcoords = textureCoordinates;

        UploadMesh(&thisMesh, false);

        if (!thisMesh.vaoId < 0) {
            throw new Error("Invalid mesh. " ~ to!string(meshID));
        }

        database[meshID] = thisMesh;

        return meshID;
    }

    pragma(inline, true)
    void prepareAtlasDrawing() {
        rlEnableShader(mainShaderID);

        static immutable float[4] COLOR_DATA = [1.0, 1.0, 1.0, 1.0];
        static immutable int UNIFORM_DATA_TYPE = ShaderUniformDataType.SHADER_UNIFORM_VEC4;

        rlSetUniform(shaderColorDiffuseUniformLocation, &COLOR_DATA, UNIFORM_DATA_TYPE, 1);

        rlActiveTextureSlot(0);
        rlSetUniform(shaderColorDiffuseUniformLocation, null, ShaderUniformDataType.SHADER_UNIFORM_INT, 1);
        rlEnableTexture(textureAtlas.id);

        matView = rlGetMatrixModelview();
        matProjection = rlGetMatrixProjection();
        matrixTransform = rlGetMatrixTransform();
    }

    pragma(inline, true);
    void draw(Vec2d position, int id) {
        import std.datetime.stopwatch;

        Mesh* thisMesh = id in database;

        if (thisMesh is null) {
            throw new Error("This is quite a strange crash. " ~
                    "This means that this thing had a mesh that didn't exist assigned to it.");
        }

        //! This part is absolutely depraved and you should look away.

        // auto sw = StopWatch(AutoStart.yes);

        // Manually inline the identity and translation and hope SIMD takes over.
        Matrix transform;
        transform.m0 = 1;
        transform.m5 = 1;
        transform.m10 = 1;
        transform.m12 = position.x;
        transform.m13 = -position.y;
        transform.m14 = 0;
        transform.m15 = 1;

        Matrix matModel;
        matModel.m0 = 1;
        matModel.m5 = 1;
        matModel.m10 = 1;
        matModel.m15 = 1;

        Matrix matModelView;
        matModelView.m0 = 1;
        matModelView.m5 = 1;
        matModelView.m10 = 1;
        matModelView.m15 = 1;

        fastMatrixMultiply(&transform, &matrixTransform, &matModel);

        // Get model-view matrix
        fastMatrixMultiply(&matModel, &matView, &matModelView);

        // Calculate model-view-projection matrix (MVP)
        Matrix matModelViewProjection;
        matModelViewProjection.m0 = 1;
        matModelViewProjection.m5 = 1;
        matModelViewProjection.m10 = 1;
        matModelViewProjection.m15 = 1;
        fastMatrixMultiply(&matModelView, &matProjection, &matModelViewProjection);

        // Send combined model-view-projection matrix to shader
        rlSetUniformMatrix(mvpUniformLocation, matModelViewProjection);

        rlEnableVertexArray(thisMesh.vaoId);
        rlDrawVertexArray(0, thisMesh.vertexCount);

        // rlDisableVertexArray();

        // long timeResult = sw.peek().total!"hnsecs";

        // writeln("total: ", timeResult / 10.0, " usecs");

    }

    void destroy(int id) {
        // 0 is reserved for null;
        if (id == 0) {
            return;
        }

        Mesh* thisMesh = id in database;

        if (thisMesh is null) {
            throw new Error(
                "Tried to destroy non-existent mesh. " ~ to!string(id));
        }

        UnloadMesh(*thisMesh);
    }



    void UploadMesh(Mesh *mesh, bool dynamic)
{
    if (mesh.vaoId > 0)
    {
        // Check if mesh has already been loaded in GPU.
        throw new Error("VAO: Trying to re-load an already loaded mesh" ~ to!string(mesh.vaoId));
    }

    mesh->vboId = (unsigned int *)RL_CALLOC(MAX_MESH_VERTEX_BUFFERS, sizeof(unsigned int));

    mesh->vaoId = 0;        // Vertex Array Object
    mesh->vboId[RL_DEFAULT_SHADER_ATTRIB_LOCATION_POSITION] = 0;     // Vertex buffer: positions
    mesh->vboId[RL_DEFAULT_SHADER_ATTRIB_LOCATION_TEXCOORD] = 0;     // Vertex buffer: texcoords
    mesh->vboId[RL_DEFAULT_SHADER_ATTRIB_LOCATION_NORMAL] = 0;       // Vertex buffer: normals
    mesh->vboId[RL_DEFAULT_SHADER_ATTRIB_LOCATION_COLOR] = 0;        // Vertex buffer: colors
    mesh->vboId[RL_DEFAULT_SHADER_ATTRIB_LOCATION_TANGENT] = 0;      // Vertex buffer: tangents
    mesh->vboId[RL_DEFAULT_SHADER_ATTRIB_LOCATION_TEXCOORD2] = 0;    // Vertex buffer: texcoords2
    mesh->vboId[RL_DEFAULT_SHADER_ATTRIB_LOCATION_INDICES] = 0;      // Vertex buffer: indices

#ifdef RL_SUPPORT_MESH_GPU_SKINNING
    mesh->vboId[RL_DEFAULT_SHADER_ATTRIB_LOCATION_BONEIDS] = 0;      // Vertex buffer: boneIds
    mesh->vboId[RL_DEFAULT_SHADER_ATTRIB_LOCATION_BONEWEIGHTS] = 0;  // Vertex buffer: boneWeights
#endif

#if defined(GRAPHICS_API_OPENGL_33) || defined(GRAPHICS_API_OPENGL_ES2)
    mesh->vaoId = rlLoadVertexArray();
    rlEnableVertexArray(mesh->vaoId);

    // NOTE: Vertex attributes must be uploaded considering default locations points and available vertex data

    // Enable vertex attributes: position (shader-location = 0)
    void *vertices = (mesh->animVertices != NULL)? mesh->animVertices : mesh->vertices;
    mesh->vboId[RL_DEFAULT_SHADER_ATTRIB_LOCATION_POSITION] = rlLoadVertexBuffer(vertices, mesh->vertexCount*3*sizeof(float), dynamic);
    rlSetVertexAttribute(RL_DEFAULT_SHADER_ATTRIB_LOCATION_POSITION, 3, RL_FLOAT, 0, 0, 0);
    rlEnableVertexAttribute(RL_DEFAULT_SHADER_ATTRIB_LOCATION_POSITION);

    // Enable vertex attributes: texcoords (shader-location = 1)
    mesh->vboId[RL_DEFAULT_SHADER_ATTRIB_LOCATION_TEXCOORD] = rlLoadVertexBuffer(mesh->texcoords, mesh->vertexCount*2*sizeof(float), dynamic);
    rlSetVertexAttribute(RL_DEFAULT_SHADER_ATTRIB_LOCATION_TEXCOORD, 2, RL_FLOAT, 0, 0, 0);
    rlEnableVertexAttribute(RL_DEFAULT_SHADER_ATTRIB_LOCATION_TEXCOORD);

    // WARNING: When setting default vertex attribute values, the values for each generic vertex attribute
    // is part of current state, and it is maintained even if a different program object is used

    if (mesh->normals != NULL)
    {
        // Enable vertex attributes: normals (shader-location = 2)
        void *normals = (mesh->animNormals != NULL)? mesh->animNormals : mesh->normals;
        mesh->vboId[RL_DEFAULT_SHADER_ATTRIB_LOCATION_NORMAL] = rlLoadVertexBuffer(normals, mesh->vertexCount*3*sizeof(float), dynamic);
        rlSetVertexAttribute(RL_DEFAULT_SHADER_ATTRIB_LOCATION_NORMAL, 3, RL_FLOAT, 0, 0, 0);
        rlEnableVertexAttribute(RL_DEFAULT_SHADER_ATTRIB_LOCATION_NORMAL);
    }
    else
    {
        // Default vertex attribute: normal
        // WARNING: Default value provided to shader if location available
        float value[3] = { 0.0f, 0.0f, 1.0f };
        rlSetVertexAttributeDefault(RL_DEFAULT_SHADER_ATTRIB_LOCATION_NORMAL, value, SHADER_ATTRIB_VEC3, 3);
        rlDisableVertexAttribute(RL_DEFAULT_SHADER_ATTRIB_LOCATION_NORMAL);
    }

    if (mesh->colors != NULL)
    {
        // Enable vertex attribute: color (shader-location = 3)
        mesh->vboId[RL_DEFAULT_SHADER_ATTRIB_LOCATION_COLOR] = rlLoadVertexBuffer(mesh->colors, mesh->vertexCount*4*sizeof(unsigned char), dynamic);
        rlSetVertexAttribute(RL_DEFAULT_SHADER_ATTRIB_LOCATION_COLOR, 4, RL_UNSIGNED_BYTE, 1, 0, 0);
        rlEnableVertexAttribute(RL_DEFAULT_SHADER_ATTRIB_LOCATION_COLOR);
    }
    else
    {
        // Default vertex attribute: color
        // WARNING: Default value provided to shader if location available
        float value[4] = { 1.0f, 1.0f, 1.0f, 1.0f };    // WHITE
        rlSetVertexAttributeDefault(RL_DEFAULT_SHADER_ATTRIB_LOCATION_COLOR, value, SHADER_ATTRIB_VEC4, 4);
        rlDisableVertexAttribute(RL_DEFAULT_SHADER_ATTRIB_LOCATION_COLOR);
    }

    if (mesh->tangents != NULL)
    {
        // Enable vertex attribute: tangent (shader-location = 4)
        mesh->vboId[RL_DEFAULT_SHADER_ATTRIB_LOCATION_TANGENT] = rlLoadVertexBuffer(mesh->tangents, mesh->vertexCount*4*sizeof(float), dynamic);
        rlSetVertexAttribute(RL_DEFAULT_SHADER_ATTRIB_LOCATION_TANGENT, 4, RL_FLOAT, 0, 0, 0);
        rlEnableVertexAttribute(RL_DEFAULT_SHADER_ATTRIB_LOCATION_TANGENT);
    }
    else
    {
        // Default vertex attribute: tangent
        // WARNING: Default value provided to shader if location available
        float value[4] = { 1.0f, 0.0f, 0.0f, 1.0f };
        rlSetVertexAttributeDefault(RL_DEFAULT_SHADER_ATTRIB_LOCATION_TANGENT, value, SHADER_ATTRIB_VEC4, 4);
        rlDisableVertexAttribute(RL_DEFAULT_SHADER_ATTRIB_LOCATION_TANGENT);
    }

    if (mesh->texcoords2 != NULL)
    {
        // Enable vertex attribute: texcoord2 (shader-location = 5)
        mesh->vboId[RL_DEFAULT_SHADER_ATTRIB_LOCATION_TEXCOORD2] = rlLoadVertexBuffer(mesh->texcoords2, mesh->vertexCount*2*sizeof(float), dynamic);
        rlSetVertexAttribute(RL_DEFAULT_SHADER_ATTRIB_LOCATION_TEXCOORD2, 2, RL_FLOAT, 0, 0, 0);
        rlEnableVertexAttribute(RL_DEFAULT_SHADER_ATTRIB_LOCATION_TEXCOORD2);
    }
    else
    {
        // Default vertex attribute: texcoord2
        // WARNING: Default value provided to shader if location available
        float value[2] = { 0.0f, 0.0f };
        rlSetVertexAttributeDefault(RL_DEFAULT_SHADER_ATTRIB_LOCATION_TEXCOORD2, value, SHADER_ATTRIB_VEC2, 2);
        rlDisableVertexAttribute(RL_DEFAULT_SHADER_ATTRIB_LOCATION_TEXCOORD2);
    }

#ifdef RL_SUPPORT_MESH_GPU_SKINNING
    if (mesh->boneIds != NULL)
    {
        // Enable vertex attribute: boneIds (shader-location = 7)
        mesh->vboId[RL_DEFAULT_SHADER_ATTRIB_LOCATION_BONEIDS] = rlLoadVertexBuffer(mesh->boneIds, mesh->vertexCount*4*sizeof(unsigned char), dynamic);
        rlSetVertexAttribute(RL_DEFAULT_SHADER_ATTRIB_LOCATION_BONEIDS, 4, RL_UNSIGNED_BYTE, 0, 0, 0);
        rlEnableVertexAttribute(RL_DEFAULT_SHADER_ATTRIB_LOCATION_BONEIDS);
    }
    else
    {
        // Default vertex attribute: boneIds
        // WARNING: Default value provided to shader if location available
        float value[4] = { 0.0f, 0.0f, 0.0f, 0.0f };
        rlSetVertexAttributeDefault(RL_DEFAULT_SHADER_ATTRIB_LOCATION_BONEIDS, value, SHADER_ATTRIB_VEC4, 4);
        rlDisableVertexAttribute(RL_DEFAULT_SHADER_ATTRIB_LOCATION_BONEIDS);
    }

    if (mesh->boneWeights != NULL)
    {
        // Enable vertex attribute: boneWeights (shader-location = 8)
        mesh->vboId[RL_DEFAULT_SHADER_ATTRIB_LOCATION_BONEWEIGHTS] = rlLoadVertexBuffer(mesh->boneWeights, mesh->vertexCount*4*sizeof(float), dynamic);
        rlSetVertexAttribute(RL_DEFAULT_SHADER_ATTRIB_LOCATION_BONEWEIGHTS, 4, RL_FLOAT, 0, 0, 0);
        rlEnableVertexAttribute(RL_DEFAULT_SHADER_ATTRIB_LOCATION_BONEWEIGHTS);
    }
    else
    {
        // Default vertex attribute: boneWeights
        // WARNING: Default value provided to shader if location available
        float value[4] = { 0.0f, 0.0f, 0.0f, 0.0f };
        rlSetVertexAttributeDefault(RL_DEFAULT_SHADER_ATTRIB_LOCATION_BONEWEIGHTS, value, SHADER_ATTRIB_VEC4, 2);
        rlDisableVertexAttribute(RL_DEFAULT_SHADER_ATTRIB_LOCATION_BONEWEIGHTS);
    }
#endif

    if (mesh->indices != NULL)
    {
        mesh->vboId[RL_DEFAULT_SHADER_ATTRIB_LOCATION_INDICES] = rlLoadVertexBufferElement(mesh->indices, mesh->triangleCount*3*sizeof(unsigned short), dynamic);
    }

    if (mesh->vaoId > 0) TRACELOG(LOG_INFO, "VAO: [ID %i] Mesh uploaded successfully to VRAM (GPU)", mesh->vaoId);
    else TRACELOG(LOG_INFO, "VBO: Mesh uploaded successfully to VRAM (GPU)");

    rlDisableVertexArray();
#endif
}

}
