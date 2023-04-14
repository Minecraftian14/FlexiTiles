package in.mcxiv.flexitiles;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.graphics.Camera;
import com.badlogic.gdx.graphics.g2d.Batch;
import com.badlogic.gdx.graphics.g2d.TextureRegion;
import com.badlogic.gdx.graphics.glutils.ShaderProgram;
import com.badlogic.gdx.math.MathUtils;
import com.badlogic.gdx.math.Vector2;
import com.badlogic.gdx.utils.Array;
import com.badlogic.gdx.utils.FloatArray;
import com.badlogic.gdx.utils.viewport.Viewport;

import static com.badlogic.gdx.math.MathUtils.lerp;

public class LinearFlexiTile {
    TextureRegion textureRegion;

    float split_start;
    float split_end;
    float height_of_tile;
    float[] guidePointX;
    float[] guidePointY;

    ShaderProgram shaderProgram;

    public LinearFlexiTile(TextureRegion textureRegion, float split_start, float split_end, float heightOfTile) {
        this.textureRegion = textureRegion;
        this.split_start = split_start;
        this.split_end = split_end;
        height_of_tile = heightOfTile;

        shaderProgram = new ShaderProgram(
            Gdx.files.internal("vertex.glsl"),
            Gdx.files.internal("fragment2.glsl")
        );
        if (!shaderProgram.isCompiled())
            Gdx.app.log("ERROR", shaderProgram.getLog());
    }

    public LinearFlexiTile(TextureRegion textureRegion, float heightOfTile) {
        this(textureRegion, 0.35f, 0.65f, heightOfTile);
    }

    public void draw(Viewport viewport, Batch batch) {
        Camera camera = viewport.getCamera();
        float worldWidth = viewport.getWorldWidth();
        float worldHeight = viewport.getWorldHeight();

        batch.setShader(shaderProgram);

        shaderProgram.setUniformf("u_splitStart", split_start);
        shaderProgram.setUniformf("u_splitEnd", split_end);
        shaderProgram.setUniformf("u_repeats", -1);
        shaderProgram.setUniformf("u_heightOfTile", height_of_tile);
        shaderProgram.setUniform1fv("u_guidePointX", guidePointX, 0, guidePointX.length);
        shaderProgram.setUniform1fv("u_guidePointY", guidePointY, 0, guidePointY.length);
        shaderProgram.setUniformi("u_numberOfGuidePoints", guidePointX.length);
        shaderProgram.setUniformf("u_resolution", worldWidth, worldHeight);
        shaderProgram.setUniformf("u_screenToWorld", worldWidth / viewport.getScreenWidth());
        shaderProgram.setUniformf("u_camera", camera.position.x, camera.position.y);

        batch.draw(textureRegion,
            camera.position.x - worldWidth / 2,
            camera.position.y - worldHeight / 2,
            worldWidth,
            worldHeight);
        batch.setShader(null);
    }

    public void updateGuidePoints(Vector2... points) {
        guidePointX = new float[points.length];
        guidePointY = new float[points.length];
        for (int i = 0; i < points.length; i++) {
            guidePointX[i] = points[i].x;
            guidePointY[i] = points[i].y;
        }
    }

    public void makePathContinuous() {
        for (int i = 4; i < guidePointX.length; i += 3)
            guidePointY[i] = lerp(guidePointY[i - 2], guidePointY[i - 1], 2);
    }

    public float bezier(float a, float b, float c, float d, float f) {
        return lerp(lerp(lerp(a, b, f), lerp(b, c, f), f), lerp(lerp(b, c, f), lerp(c, d, f), f), f);
    }

    public Array<FloatArray> createShape() {
        return createShape((int) (2 * (Vector2.dst(guidePointX[0], guidePointY[0], guidePointX[1], guidePointY[1])
                                       + Vector2.dst(guidePointX[1], guidePointY[1], guidePointX[2], guidePointY[2])) / height_of_tile));
    }

    public Array<FloatArray> createShape(int resolution) {
        Array<FloatArray> points = new Array<>();
        for (int i = 0; i < (guidePointX.length - 1) / 3; i++)
            points.addAll(createShape(resolution, 3 * i));
        return points;
    }

    public Array<FloatArray> createShape(int resolution, int offset) {
        Array<FloatArray> shapes = new Array<>();

        float pmab = MathUtils.atan2(guidePointX[offset + 1] - guidePointX[offset + 0], guidePointY[offset + 1] - guidePointY[offset + 0]);
        float pmbc = MathUtils.atan2(guidePointX[offset + 2] - guidePointX[offset + 1], guidePointY[offset + 2] - guidePointY[offset + 1]);
        float pmcd = MathUtils.atan2(guidePointX[offset + 3] - guidePointX[offset + 2], guidePointY[offset + 3] - guidePointY[offset + 2]);
        float ax1 = guidePointX[offset + 0] - height_of_tile * MathUtils.cos(pmab), ay1 = guidePointY[offset + 0] + height_of_tile * MathUtils.sin(pmab);
        float bx1 = guidePointX[offset + 1] - height_of_tile * MathUtils.cos((pmab + pmbc) / 2), by1 = guidePointY[offset + 1] + height_of_tile * MathUtils.sin((pmab + pmbc) / 2);
        float cx1 = guidePointX[offset + 2] - height_of_tile * MathUtils.cos((pmbc + pmcd) / 2), cy1 = guidePointY[offset + 2] + height_of_tile * MathUtils.sin((pmbc + pmcd) / 2);
        float dx1 = guidePointX[offset + 3] - height_of_tile * MathUtils.cos(pmcd), dy1 = guidePointY[offset + 3] + height_of_tile * MathUtils.sin(pmcd);
        float ax2 = guidePointX[offset + 0], ay2 = guidePointY[offset + 0];
        float bx2 = guidePointX[offset + 1], by2 = guidePointY[offset + 1];
        float cx2 = guidePointX[offset + 2], cy2 = guidePointY[offset + 2];
        float dx2 = guidePointX[offset + 3], dy2 = guidePointY[offset + 3];

        for (int i = 0; i < resolution; i++) {
            FloatArray points = new FloatArray();
            float f = i * 1f / resolution;
            float f1 = (i + 1f) / resolution;
            points.add(
                bezier(ax1, bx1, cx1, dx1, f),
                bezier(ay1, by1, cy1, dy1, f)
            );
            points.add(
                bezier(ax1, bx1, cx1, dx1, f1),
                bezier(ay1, by1, cy1, dy1, f1)
            );
            points.add(
                bezier(ax2, bx2, cx2, dx2, f1),
                bezier(ay2, by2, cy2, dy2, f1)
            );
            points.add(
                bezier(ax2, bx2, cx2, dx2, f),
                bezier(ay2, by2, cy2, dy2, f)
            );
            shapes.add(points);
        }

        return shapes;
    }
}
