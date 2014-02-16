hxGeomAlgo
==========

Small collection of geometry algorithms in Haxe 3.

![](screenshot.png)

### [Marching Squares](http://en.wikipedia.org/wiki/Marching_squares) ###


Adapted/modified from:

 - [http://devblog.phillipspiess.com/2010/02/23/better-know-an-algorithm-1-marching-squares/](http://devblog.phillipspiess.com/2010/02/23/better-know-an-algorithm-1-marching-squares/)	(C# - by Phil Spiess)
 - [http://www.tomgibara.com/computer-vision/marching-squares](http://www.tomgibara.com/computer-vision/marching-squares)	(Java - by Tom Gibara)

Relevant changes:

 - Fixed bug where it wouldn't work on fully opaque bitmapdata
 - Alpha threshold parameter
 - Recognize illegal states
 - ClipRect support

### [Ramer-Douglas-Peucker](http://en.wikipedia.org/wiki/Ramer%E2%80%93Douglas%E2%80%93Peucker_algorithm) ###


Adapted/modified from:

 - [http://karthaus.nl/rdp/](http://karthaus.nl/rdp/) (JS - by Marius Karthaus)
 - [http://stackoverflow.com/questions/849211/shortest-distance-between-a-point-and-a-line-segment](http://stackoverflow.com/questions/849211/shortest-distance-between-a-point-and-a-line-segment)	(JS - Grumdrig)

Relevant changes:

 - Fixed bug where it wouldn't work on circle-like polylines
 - Ported Grumdrig's distanceToSegment to use in place of Karthaus' perpendicularDistance

### [Ear Clipping](http://en.wikipedia.org/wiki/Ear_clipping#Ear_clipping_method) ###


Adapted/modified from:

 - [http://www.box2d.org/forum/viewtopic.php?f=8&t=463&start=0](http://www.box2d.org/forum/viewtopic.php?f=8&t=463&start=0)	(JSFL - by mayobutter)
 - [http://www.ewjordan.com/earClip/](http://www.ewjordan.com/earClip/)			(Processing - by Eric Jordan)
 - [http://blog.touchmypixel.com/2008/06/making-convex-polygons-from-concave-ones-ear-clipping/](http://blog.touchmypixel.com/2008/06/making-convex-polygons-from-concave-ones-ear-clipping/) 	(AS3 - by Tarwin Stroh-Spijer)
 - [http://headsoft.com.au/](http://headsoft.com.au/)	(C# - by Ben Baker)

Relevant changes:

 - Support array of points instead of flat arrays

