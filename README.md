# FlexiTiles

Use shaders to stretch-n-repeat tile images to fill a spline.

That is, convert

<img width="500" src="https://user-images.githubusercontent.com/52451860/232027188-fe86458a-5b1e-4856-9166-ef7c9d3f0f86.png"></img>

to

<img width="500" src="https://user-images.githubusercontent.com/52451860/232027420-619ef81f-7f7f-41fd-a31d-1c2cbb711904.gif"></img>


Check out [Flexi Tiles Demo](https://github.com/Minecraftian14/FlexiTilesDemo) for code examples.

### How to use?

First of all, create an instance of LinearFlexiTile. This class contains the driver code to make drawing simple. 
If this does not work in your specific environment (project setup) then please file an issue.
```java
/**
 * tile - The source texture region which is extended and reshaped.
 * start and end - the fraction of tile which will be repeated. Raneg must be within 0 to 1 only.
 * height - The height of the tile you wish to maintain (in world units).
 */
var flexiTile = new LinearFlexiTile(tile, start, end, height);
```

Then make an `Array` of points and add all the spline points.
The first point is the starter point, the fourth point is the bezier ender. The two points in between are the control points. Further, the fourth point also acts as the starter point for the next bezier.
```java
points.addAll(
    new Vector2(-3, -1),
    new Vector2(-3, 0),
    new Vector2(-1, -1),
    new Vector2(0, -.1f),
    new Vector2(1, 1),
    new Vector2(2, -1),
    new Vector2(3, 1)
);
```

To update the `flexiTile`, call the following methods
```java
// Set the points in flexiTile 
flexiTile.updateGuidePoints(points.toArray(Vector2.class));
// Reset first control point of beziers to make spline continuous
flexiTile.makePathContinuous();
```

And finally draw the tile ✨
```java
// batch.setProjectionMatrix(camera.combined);
// batch.begin();

floorTile.draw(viewport, batch);

// batch.draw(...);
// batch.end();
```

Moreover, you can add Physics!!
```java
// Create a list of points representing shapes which describe the spline. Optionally pass a resolution number if you want smoother shapes.  
var shapes = floorTile.createShape();

// Add these shapes to any physics engine of you choice. For example, in kbox 2d you can write as
BodyDef def = new BodyDef();
def.position.set(0, 0);
Body body = world.createBody(def);
Array<FloatArray> shapes = floorTile.createShape(100);
for (int j = 0; j < shapes.size; j++) {
    PolygonShape s = new PolygonShape();
    s.set(shapes.get(j).toArray());
    body.createFixture(s, 0.0f);
    s.dispose();
}
```
