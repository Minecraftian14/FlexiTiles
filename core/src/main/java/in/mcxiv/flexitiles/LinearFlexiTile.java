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
    float[] guidePointX = new float[3];
    float[] guidePointY = new float[3];

    ShaderProgram shaderProgram;

    public LinearFlexiTile(TextureRegion textureRegion, float split_start, float split_end, float heightOfTile) {
        this.textureRegion = textureRegion;
        this.split_start = split_start;
        this.split_end = split_end;
        height_of_tile = heightOfTile;

        shaderProgram = new ShaderProgram(
            Gdx.files.internal("vertex.glsl"),
            Gdx.files.internal("fragment.glsl")
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
//        shaderProgram.setUniformf("u_repeats", 8);
        shaderProgram.setUniformf("u_heightOfTile", height_of_tile);
        shaderProgram.setUniform1fv("u_guidePointX", guidePointX, 0, 3);
        shaderProgram.setUniform1fv("u_guidePointY", guidePointY, 0, 3);
//        shaderProgram.setUniformi("u_numberOfGuidePoints", 3);
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

    public void updateGuidePoints(Vector2 pointA, Vector2 pointB, Vector2 pointC) {
        guidePointX[0] = pointA.x;
        guidePointX[1] = pointB.x;
        guidePointX[2] = pointC.x;
        guidePointY[0] = pointA.y;
        guidePointY[1] = pointB.y;
        guidePointY[2] = pointC.y;
    }

    public Array<FloatArray> createShape() {
        return createShape((int) (2 * (Vector2.dst(guidePointX[0], guidePointY[0], guidePointX[1], guidePointY[1])
                                       + Vector2.dst(guidePointX[1], guidePointY[1], guidePointX[2], guidePointY[2])) / height_of_tile));
    }

    public Array<FloatArray> createShape(int resolution) {
        Array<FloatArray> shapes = new Array<>();

        float pmab = MathUtils.atan2(guidePointX[1] - guidePointX[0], guidePointY[1] - guidePointY[0]);
        float pmbc = MathUtils.atan2(guidePointX[2] - guidePointX[1], guidePointY[2] - guidePointY[1]);
        float ax1 = guidePointX[0] - height_of_tile * MathUtils.cos(pmab), ay1 = guidePointY[0] + height_of_tile * MathUtils.sin(pmab);
        float bx1 = guidePointX[1] - height_of_tile * MathUtils.cos((pmab + pmbc) / 2), by1 = guidePointY[1] + height_of_tile * MathUtils.sin((pmab + pmbc) / 2);
        float cx1 = guidePointX[2] - height_of_tile * MathUtils.cos(pmbc), cy1 = guidePointY[2] + height_of_tile * MathUtils.sin(pmbc);
        float ax2 = guidePointX[0], ay2 = guidePointY[0];
        float bx2 = guidePointX[1], by2 = guidePointY[1];
        float cx2 = guidePointX[2], cy2 = guidePointY[2];

        for (int i = 0; i < resolution; i++) {
            FloatArray points = new FloatArray();
            float f = i * 1f / resolution;
            float f1 = (i + 1f) / resolution;
            points.add(
                lerp(lerp(ax1, bx1, f), lerp(bx1, cx1, f), f),
                lerp(lerp(ay1, by1, f), lerp(by1, cy1, f), f)
            );
            points.add(
                lerp(lerp(ax1, bx1, f1), lerp(bx1, cx1, f1), f1),
                lerp(lerp(ay1, by1, f1), lerp(by1, cy1, f1), f1)
            );
            points.add(
                lerp(lerp(ax2, bx2, f1), lerp(bx2, cx2, f1), f1),
                lerp(lerp(ay2, by2, f1), lerp(by2, cy2, f1), f1)
            );
            points.add(
                lerp(lerp(ax2, bx2, f), lerp(bx2, cx2, f), f),
                lerp(lerp(ay2, by2, f), lerp(by2, cy2, f), f)
            );
            shapes.add(points);
        }

        return shapes;
    }

}
