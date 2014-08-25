hxGeomAlgo
==========

Small collection of geometry algorithms in Haxe 3. ([link to AS3 port](https://github.com/azrafe7/as3GeomAlgo))

![](screenshot.png)

**NOTE: All algorithms assume the y-axis is pointing downward.**

#### [Marching Squares (Contour Tracing)](http://en.wikipedia.org/wiki/Marching_squares)

Based on:

 - [http://devblog.phillipspiess.com/2010/02/23/better-know-an-algorithm-1-marching-squares/](http://devblog.phillipspiess.com/2010/02/23/better-know-an-algorithm-1-marching-squares/)	(C# - by Phil Spiess)
 - [http://www.tomgibara.com/computer-vision/marching-squares](http://www.tomgibara.com/computer-vision/marching-squares)	(Java - by Tom Gibara)

#### [Ramer-Douglas-Peucker (Polyline Simplification)](http://en.wikipedia.org/wiki/Ramer%E2%80%93Douglas%E2%80%93Peucker_algorithm)

Based on:

 - [http://karthaus.nl/rdp/](http://karthaus.nl/rdp/) (JS - by Marius Karthaus)
 - [http://stackoverflow.com/questions/849211/shortest-distance-between-a-point-and-a-line-segment](http://stackoverflow.com/questions/849211/shortest-distance-between-a-point-and-a-line-segment)	(JS - Grumdrig)

#### [Ear Clipping (Triangulation and Poly Decomposition)](http://en.wikipedia.org/wiki/Ear_clipping#Ear_clipping_method)

Based on:

 - [http://www.box2d.org/forum/viewtopic.php?f=8&t=463&start=0](http://www.box2d.org/forum/viewtopic.php?f=8&t=463&start=0)	(JSFL - by mayobutter)
 - [http://www.ewjordan.com/earClip/](http://www.ewjordan.com/earClip/)			(Processing - by Eric Jordan)
 - [http://en.nicoptere.net/?p=16](http://en.nicoptere.net/?p=16) (AS3 - by Nicolas Barradeau)
 - [http://blog.touchmypixel.com/2008/06/making-convex-polygons-from-concave-ones-ear-clipping/](http://blog.touchmypixel.com/2008/06/making-convex-polygons-from-concave-ones-ear-clipping/) 	(AS3 - by Tarwin Stroh-Spijer)
 - [http://headsoft.com.au/](http://headsoft.com.au/)	(C# - by Ben Baker)

#### [Bayazit (Poly Decomposition)](http://mnbayazit.com/406/overview)

Based on:

 - [http://mnbayazit.com/406/bayazit](http://mnbayazit.com/406/bayazit)	(C - by Mark Bayazit)

#### [Visibilty Polygon](http://en.wikipedia.org/wiki/Visibility_polygon) and [Homogeneous Coords (2D)](http://en.wikipedia.org/wiki/Homogeneous_coordinates)

Based on:

 - [http://www.cs.ubc.ca/~snoeyink/demos/convdecomp/VPDemo.html](http://www.cs.ubc.ca/~snoeyink/demos/convdecomp/VPDemo.html)	(Java - by Jack Snoeyink)

#### [Snoeyink-Keil (Minimum Convex Decomposition)](http://www.cs.ubc.ca/~snoeyink/demos/convdecomp/MCDDemo.html)

Based on:

   - [http://www.cs.ubc.ca/~snoeyink/demos/convdecomp/MCDDemo.html](http://www.cs.ubc.ca/~snoeyink/demos/convdecomp/MCDDemo.html) (Java - by Jack Snoeyink & Mark Keil)
   - [J. Mark Keil](http://www.informatik.uni-trier.de/~ley/pers/hd/k/Keil:J=_Mark), [Jack Snoeyink](http://www.informatik.uni-trier.de/~ley/pers/hd/s/Snoeyink:Jack.html): On the Time Bound for Convex Decomposition of Simple Polygons. [Int. J. Comput. Geometry Appl. 12](http://www.informatik.uni-trier.de/~ley/db/journals/ijcga/ijcga12.html#KeilS02)(3): 181-192 (2002)

#### [Connected Components Labeling (with optional Contour Tracing)](http://en.wikipedia.org/wiki/Connected-component_labeling)

Based on:

 - Fu Chang, Chun-jen Chen, Chi-jen Lu: [A linear-time component-labeling algorithm using contour tracing technique](http://www.iis.sinica.edu.tw/papers/fchang/1362-F.pdf) (2004)

#### [Visvalingam-Whyatt (Polyline Simplification)](http://bost.ocks.org/mike/simplify/)

Based on:

 - Visvalingam M., Whyatt J. D.: [Line generalisation by repeated elimination of the smallest area](https://hydra.hull.ac.uk/resources/hull:8338) (1992)
 - [http://bost.ocks.org/mike/simplify/](http://bost.ocks.org/mike/simplify/) (JS - by Mike Bostock)
 - [http://en.wikipedia.org/wiki/Binary_heap](http://en.wikipedia.org/wiki/Binary_heap) (Binary (Min)Heap)


## Credits

**hxGeomAlgo** is based on the work of many developers and it wouldn't exist if it weren't for them. See the [CREDITS](CREDITS.md) file for details.

## License

**hxGeomAlgo** is developed by Giuseppe Di Mauro (azrafe7) and released under the MIT license. See the [LICENSE](LICENSE.md) file for details. 