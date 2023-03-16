package in.mcxiv.flexitiles;

import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.graphics.Camera;
import com.badlogic.gdx.graphics.GL20;
import com.badlogic.gdx.graphics.g2d.Batch;
import com.badlogic.gdx.graphics.g2d.TextureRegion;
import com.badlogic.gdx.graphics.glutils.ShaderProgram;
import com.badlogic.gdx.math.Vector2;
import com.badlogic.gdx.utils.viewport.Viewport;

public class LinearFlexiTile {
    TextureRegion textureRegion;

    float split_start;
    float split_end;
    float[] guidePointX = new float[3];
    float[] guidePointY = new float[3];

    ShaderProgram shaderProgram;

    public LinearFlexiTile(TextureRegion textureRegion, float split_start, float split_end) {
        this.textureRegion = textureRegion;
        this.split_start = split_start;
        this.split_end = split_end;

        shaderProgram = new ShaderProgram(
            Gdx.files.internal("vertex.glsl"),
//            Gdx.files.internal("fragment_warp_only.glsl")
            Gdx.files.internal("fragment_again.glsl")
        );
        if (!shaderProgram.isCompiled())
            Gdx.app.log("ERROR", shaderProgram.getLog());
    }

    public LinearFlexiTile(TextureRegion textureRegion) {
        this(textureRegion, 0.35f, 0.65f);
    }

    public void draw(Viewport viewport, Batch batch) {
        Camera camera = viewport.getCamera();
        float worldWidth = viewport.getWorldWidth();
        float worldHeight = viewport.getWorldHeight();

        batch.setShader(shaderProgram);

        shaderProgram.setUniformf("u_splitStart", split_start);
        shaderProgram.setUniformf("u_splitEnd", split_end);
        shaderProgram.setUniformf("u_repeats", 6);
        shaderProgram.setUniform1fv("u_guidePointX", guidePointX, 0, 3);
        shaderProgram.setUniform1fv("u_guidePointY", guidePointY, 0, 3);
        textureRegion.getTexture().bind(shaderProgram.fetchUniformLocation("iChannel0", false));

//        shaderProgram.setUniformi("u_numberOfGuidePoints", 3);

        batch.draw(textureRegion,
            camera.position.x - worldWidth / 2,
            camera.position.y - worldHeight / 2,
            worldWidth,
            worldHeight);
        batch.setShader(null);
    }

    public void updateGuidePoints(Vector2 pointA, Vector2 pointB, Vector2 pointC, Viewport viewport) {
        Camera camera = viewport.getCamera();
        float reciprocal = 2f / viewport.getWorldWidth();
        guidePointX[0] = pointA.x * reciprocal;
        guidePointX[1] = pointB.x * reciprocal;
        guidePointX[2] = pointC.x * reciprocal;
        guidePointY[0] = pointA.y * reciprocal;
        guidePointY[1] = pointB.y * reciprocal;
        guidePointY[2] = pointC.y * reciprocal;
    }
}
