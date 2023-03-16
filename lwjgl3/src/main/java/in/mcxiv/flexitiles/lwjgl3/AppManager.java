package in.mcxiv.flexitiles.lwjgl3;

import com.badlogic.gdx.ApplicationAdapter;
import com.badlogic.gdx.Gdx;
import com.badlogic.gdx.Input;
import com.badlogic.gdx.graphics.*;
import com.badlogic.gdx.graphics.g2d.SpriteBatch;
import com.badlogic.gdx.graphics.g2d.TextureRegion;
import com.badlogic.gdx.math.Vector2;
import com.badlogic.gdx.utils.viewport.ExtendViewport;
import in.mcxiv.flexitiles.LinearFlexiTile;

/**
 * {@link com.badlogic.gdx.ApplicationListener} implementation shared by all platforms.
 */
public class AppManager extends ApplicationAdapter {

    private OrthographicCamera camera;
    private ExtendViewport viewport;
    private SpriteBatch batch;
    private Texture image;
    private Texture cursor;
    private LinearFlexiTile flexiTile;

    Vector2 pointA = new Vector2(.1f, .1f);
    Vector2 pointB = new Vector2(1.f, .2f);
    Vector2 pointC = new Vector2(1.4f, .7f);
    Vector2 point = new Vector2();
    Vector2 cache = new Vector2();

    @Override
    public void create() {
        camera = new OrthographicCamera(Gdx.graphics.getWidth(), Gdx.graphics.getHeight());
//        camera.position.set(camera.viewportWidth, camera.viewportHeight, 0).scl(0.5f);
        viewport = new ExtendViewport(camera.viewportWidth, camera.viewportHeight, camera);
        batch = new SpriteBatch();

        image = new Texture(Gdx.files.internal("tile.png"), Pixmap.Format.RGBA8888, false);
        image.setWrap(Texture.TextureWrap.Repeat, Texture.TextureWrap.Repeat);
        image.setFilter(Texture.TextureFilter.MipMapLinearLinear, Texture.TextureFilter.Linear);
        Gdx.gl.glGenerateMipmap(GL20.GL_TEXTURE_2D);

        cursor = new Texture("cursor.png");

        flexiTile = new LinearFlexiTile(new TextureRegion(image));
    }

    @Override
    public void render() {
        Gdx.gl.glClearColor(0.15f, 0.15f, 0.2f, 1f);
        Gdx.gl.glClear(GL20.GL_COLOR_BUFFER_BIT);

        if (Gdx.input.isKeyPressed(Input.Keys.UP))
            camera.position.add(0, 100 * Gdx.graphics.getDeltaTime(), 0);
        if (Gdx.input.isKeyPressed(Input.Keys.DOWN))
            camera.position.add(0, -100 * Gdx.graphics.getDeltaTime(), 0);
        if (Gdx.input.isKeyPressed(Input.Keys.RIGHT))
            camera.position.add(100 * Gdx.graphics.getDeltaTime(), 0, 0);
        if (Gdx.input.isKeyPressed(Input.Keys.LEFT))
            camera.position.add(-100 * Gdx.graphics.getDeltaTime(), 0, 0);
        camera.update();

        if (Gdx.input.isTouched()) {
            viewport.unproject(point.set(Gdx.input.getX(), Gdx.input.getY()));
            float a = cache.set(point).sub(pointA).len2();
            float b = cache.set(point).sub(pointB).len2();
            float c = cache.set(point).sub(pointC).len2();
            if (a < b && a < c) pointA.set(point);
            else if (b < c) pointB.set(point);
            else pointC.set(point);
        }

        flexiTile.updateGuidePoints(pointA, pointB, pointC, viewport);

        batch.setProjectionMatrix(camera.combined);
        batch.begin();
        flexiTile.draw(viewport, batch);
        batch.setColor(Color.WHITE);
        batch.draw(image, 0, 0, 100, 100);
        batch.setColor(Color.RED);
        batch.draw(cursor, pointA.x, pointA.y);
        batch.setColor(Color.GREEN);
        batch.draw(cursor, pointB.x, pointB.y);
        batch.setColor(Color.BLUE);
        batch.draw(cursor, pointC.x, pointC.y);
        batch.end();
    }

    @Override
    public void resize(int width, int height) {
        viewport.update(width, height);
    }

    @Override
    public void dispose() {
        batch.dispose();
        image.dispose();
        cursor.dispose();
    }
}
