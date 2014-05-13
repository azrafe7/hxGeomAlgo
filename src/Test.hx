package;


import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.display.Graphics;
import flash.display.Sprite;
import flash.display.Stage;
import flash.events.KeyboardEvent;
import flash.filters.GlowFilter;
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.Lib;
import flash.system.System;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;
import hxGeomAlgo.EarClipper;
import hxGeomAlgo.MarchingSquares;
import hxGeomAlgo.PolyTools;
import hxGeomAlgo.RamerDouglasPeucker;
import hxGeomAlgo.Bayazit;
import hxGeomAlgo.Visibility;
import hxGeomAlgo.PolyTools.Poly;
import hxGeomAlgo.PairDeque;
import hxGeomAlgo.SnoeyinkKeil;
import openfl.Assets;
import openfl.display.FPS;


class Test extends Sprite {

	private var g:Graphics;

	//private var ASSET:String = "assets/super_mario.png";	// from here http://www.newgrounds.com/art/view/petelavadigger/super-mario-pixel
	private var ASSET:String = "assets/pirate_small.png";
	//private var ASSET:String = "assets/nazca_monkey.png";
	//private var ASSET:String = "assets/star.png";
	//private var ASSET:String = "assets/complex.png";	// Bayazit doesn't play well with this one
	
	private var COLOR:Int = 0xFF0000;
	private var ALPHA:Float = 1.;
	private var X_GAP:Int = 10;
	private var Y_GAP:Int = 25;

	private var TEXT_COLOR:Int = 0xFFFFFFFF;
	private var TEXT_FONT:String = "_typewriter";
	private var TEXT_SIZE:Float = 12;
	private var TEXT_OFFSET:Float = -60;
	private var TEXT_OUTLINE:GlowFilter = new GlowFilter(0xFF000000, 1, 2, 2, 6);

	private var START_POINT:Point = new Point(20, 80);

	private var originalBMD:BitmapData;
	private var originalBitmap:Bitmap;

	private var marchingSquares:MarchingSquares;
	private var clipRect:Rectangle;
	private var perimeter:Array<Point>;

	private var simplifiedPoly:Array<Point>;
	private var triangulation:Array<Tri>;
	private var decomposition:Array<Poly>;


	public function new () {
		super ();

		var sprite = new Sprite();
		addChild(sprite);
		g = sprite.graphics;
		g.lineStyle(1, COLOR, ALPHA);
		originalBMD = Assets.getBitmapData(ASSET);

		var x = START_POINT.x;
		var y = START_POINT.y;
		var width = originalBMD.width;

		// ORIGINAL IMAGE
		addChildAt(originalBitmap = new Bitmap(originalBMD), 0);	// add it underneath sprite
		originalBitmap.x = x;
		originalBitmap.y = y;
		addChild(getTextField("Original\n" + originalBMD.width + "x" + originalBMD.height, x, y));

		// MARCHING SQUARES
		x += width + X_GAP;
		//clipRect = new Rectangle(10, 20, 90, 65);
		clipRect = originalBMD.rect;
		marchingSquares = new MarchingSquares(originalBMD, 1, clipRect);
		perimeter = marchingSquares.march();
		drawPerimeter(perimeter, x + clipRect.x, y + clipRect.y);
		addChild(getTextField("MarchSqrs\n" + perimeter.length + " pts", x, y));

		// RAMER-DOUGLAS-PEUCKER
		x += width + X_GAP;
		simplifiedPoly = RamerDouglasPeucker.simplify(perimeter, 1.5);
		drawPoly(simplifiedPoly, x + clipRect.x, y + clipRect.y);
		addChild(getTextField("Doug-Peuck\n" + simplifiedPoly.length + " pts", x, y));

		// EARCLIPPER TRIANGULATION
		x += width + X_GAP;
		triangulation = EarClipper.triangulate(simplifiedPoly);
		drawTriangulation(triangulation, x + clipRect.x, y + clipRect.y);
		addChild(getTextField("EC-Triang\n" + triangulation.length + " tris", x, y));

		// VISIBILITY
		x += width + X_GAP;
		drawPoly(simplifiedPoly, x, y);
		var origIdx = Std.int(Math.random() * simplifiedPoly.length);
		var origPoint = simplifiedPoly[origIdx];
		// visible points
		var visPoints = Visibility.getVisiblePolyFrom(simplifiedPoly, origIdx);
		g.lineStyle(1, 0xFFFF00);
		drawPoly(visPoints, x, y);	
		// visible vertices
		var visIndices = Visibility.getVisibleIndicesFrom(simplifiedPoly, origIdx);
		var visVertices = [for (i in 0...visIndices.length) simplifiedPoly[visIndices[i]]];
		g.lineStyle(1, 0x00FF00);
		drawPoints(visVertices, x, y);
		// draw origPoint
		g.lineStyle(1, 0x0000FF);
		g.drawCircle(x + origPoint.x, y + origPoint.y, 3);
		addChild(getTextField("Visibility\n" + visVertices.length + " vts\n" + visPoints.length + " pts", x, y));
		g.lineStyle(1, COLOR, ALPHA);

		// EARCLIPPER DECOMPOSITION
		x = START_POINT.x + width + X_GAP;
		y += height + Y_GAP;
		decomposition = EarClipper.polygonizeTriangles(triangulation);
		drawDecomposition(decomposition, x + clipRect.x, y + clipRect.y);
		addChild(getTextField("EarClipper\nDecomp\n" + decomposition.length + " polys", x, y));

		// BAYAZIT DECOMPOSITION
		x += width + X_GAP;
		decomposition = Bayazit.decomposePoly(simplifiedPoly);
		drawDecompositionBayazit(decomposition, x + clipRect.x, y + clipRect.y);
		addChild(getTextField("Bayazit\nDecomp\n" + decomposition.length + " polys", x, y));

		// SNOEYINK-KEIL DECOMPOSITION (buggy)
		x += width + X_GAP;
		decomposition = SnoeyinkKeil.decomposePoly(simplifiedPoly);
		drawDecomposition(decomposition, x + clipRect.x, y + clipRect.y);
		addChild(getTextField("Snoeyink-Keil\nMin Decomp\n" + decomposition.length + " polys", x, y));

		//stage.addChild(new FPS(5, 5, 0xFFFFFF));
		stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);

		dumpPoly(simplifiedPoly, false);
	}

	public function dumpPoly(poly:Array<Point>, reverse:Bool = false):Void {
		var len = poly.length;
		var str = "poly dump: ";
		for (i in 0...len) {
			var p = poly[reverse ? len - i - 1 : i];
			str += p.x + "," + p.y + ",";
		}
		trace(str);
	}

	public function drawPerimeter(points:Array<Point>, x:Float, y:Float):Void 
	{
		// draw clipRect
		g.drawRect(originalBitmap.x + clipRect.x, originalBitmap.y + clipRect.y, clipRect.width, clipRect.height);

		drawPoly(points, x, y, false);
	}

	public function drawPoints(points:Array<Point>, x:Float, y:Float, radius:Float = 2):Void 
	{
		for (i in 0...points.length) {
			var p = points[i];
			g.drawCircle(x + p.x, y + p.y, radius);
		}
	}
	
	public function drawPointsLabels(points:Array<Point>, x:Float, y:Float):Void 
	{
		var len = points.length;
		var i = len - 1;
		while (i >= 0) {
			var p = points[i];
			var label = getTextField("" + i, 0, 0, TEXT_SIZE * .75);
			var fmt = label.getTextFormat();
			fmt.align = TextFormatAlign.LEFT;
			label.setTextFormat(fmt);
			label.x = x + p.x;
			label.y = y + p.y - TEXT_SIZE;
			addChild(label);
			i--;
		}
	}
	
	public function drawPoly(points:Array<Point>, x:Float, y:Float, showPoints:Bool = true, showLabels:Bool = false):Void 
	{
		// points
		if (showPoints) drawPoints(points, x, y);
		
		// lines
		g.moveTo(x + points[0].x, y + points[0].y);
		for (i in 1...points.length) {
			var p = points[i];
			g.lineTo(x + p.x, y + p.y);
		}
		g.lineTo(x + points[0].x, y + points[0].y);
		
		// labels
		if (showLabels) drawPointsLabels(points, x, y);
	}

	public function drawTriangulation(tris:Array<Tri>, x:Float, y:Float):Void 
	{
		for (tri in tris) {
			var points = tri;
			g.moveTo(x + points[0].x, y + points[0].y);

			for (i in 1...points.length + 1) {
				var p = points[i % points.length];
				g.lineTo(x + p.x, y + p.y);
			}
		}
	}

	public function drawDecomposition(polys:Array<Poly>, x:Float, y:Float, showPoints:Bool = false, showLabels:Bool = false):Void 
	{
		for (poly in polys) {
			drawPoly(poly, x, y, showPoints, showLabels);
		}
	}

	public function drawDecompositionBayazit(polys:Array<Poly>, x:Float, y:Float, showPoints:Bool = false, showLabels:Bool = false, showReflex:Bool = false, showSteiner:Bool = false):Void 
	{
		drawDecomposition(polys, x, y, showPoints, showLabels);
		
		// draw Reflex and Steiner points
		if (showReflex) {
			g.lineStyle(1, (COLOR >> 1) | COLOR, ALPHA);
			for (p in Bayazit.reflexVertices) g.drawCircle(x + p.x, y + p.y, 2);
		}
		
		if (showSteiner) {
			g.lineStyle(1, (COLOR >> 2) | COLOR, ALPHA);
			for (p in Bayazit.steinerPoints) g.drawCircle(x + p.x, y + p.y, 2);
		}
		g.lineStyle(1, COLOR, ALPHA);
	}

	public function getTextField(text:String = "", x:Float, y:Float, ?size:Float):TextField
	{
		var tf:TextField = new TextField();
		var fmt:TextFormat = new TextFormat(TEXT_FONT, null, TEXT_COLOR);
		fmt.align = TextFormatAlign.CENTER;
		fmt.size = size == null ? TEXT_SIZE : size;
		tf.defaultTextFormat = fmt;
		tf.selectable = false;
		tf.x = x;
		tf.y = y + TEXT_OFFSET;
		tf.filters = [TEXT_OUTLINE];
		tf.text = text;
		return tf;
	}

	public function onKeyDown(e:KeyboardEvent):Void 
	{
		if (e.keyCode == 27) {
		#if (flash || html5)
			System.exit(1);
		#else
			Sys.exit(1);
		#end
		}
	}
}