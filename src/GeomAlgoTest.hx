package;

import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.display.Graphics;
import flash.display.Sprite;
import flash.display.Stage;
import flash.events.KeyboardEvent;
import flash.filters.GlowFilter;
import flash.geom.Rectangle;
import flash.Lib;
import flash.system.System;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.TextFormatAlign;

import hxGeomAlgo.Version;
import hxGeomAlgo.EarClipper;
import hxGeomAlgo.HxPoint;
import hxGeomAlgo.MarchingSquares;
import hxGeomAlgo.PolyTools;
import hxGeomAlgo.RamerDouglasPeucker;
import hxGeomAlgo.Bayazit;
import hxGeomAlgo.Visibility;
import hxGeomAlgo.PolyTools.Poly;
import hxGeomAlgo.PairDeque;
import hxGeomAlgo.SnoeyinkKeil;
import hxGeomAlgo.CCLabeler;
import hxGeomAlgo.VisvalingamWhyatt;
import hxGeomAlgo.Tess2;

import openfl.Assets;
import openfl.display.FPS;
import openfl.geom.Point;
import openfl.utils.ByteArray;
import openfl.text.TextFieldAutoSize;

#if (neko)
import sys.io.File;
import sys.io.FileOutput;
#end


class GeomAlgoTest extends Sprite {

	private var g:Graphics;

	//private var ASSET:String = "assets/super_mario.png";	// from http://www.newgrounds.com/art/view/petelavadigger/super-mario-pixel
	private var ASSET:String = "assets/pirate_small.png";
	//private var ASSET:String = "assets/nazca_monkey.png";
	//private var ASSET:String = "assets/star.png";
	//private var ASSET:String = "assets/text.png";
	//private var ASSET:String = "assets/complex.png";		// Bayazit doesn't play well with this one
	
	private var COLOR:Int = 0xFF0000;
	private var ALPHA:Float = 1.;
	private var X_GAP:Int = 10;
	private var Y_GAP:Int = 25;

	private var TEXT_COLOR:Int = 0xFFFFFFFF;
	private var TEXT_FONT:String = "_typewriter";
	private var TEXT_SIZE:Float = 12;
	private var TEXT_OFFSET:Float = -60;
	private var TEXT_OUTLINE:GlowFilter = new GlowFilter(0xFF000000, 1, 2, 2, 6);

	private var START_POINT:HxPoint = new HxPoint(20, 80);

	var X:Float;
	var Y:Float;
	var WIDTH:Float;
	var HEIGHT:Float;

	private var originalBMD:BitmapData;
	private var originalBitmap:Bitmap;

	private var marchingSquares:MarchingSquares;
	private var clipRect:Rectangle;
	private var perimeter:Array<HxPoint>;

	private var simplifiedPolyRDP:Array<HxPoint>;
	private var triangulation:Array<Tri>;
	private var decomposition:Array<Poly>;

	var text:TextField;
	var labelBMP:Bitmap;
	
	public function new() {
		super();

		var sprite = new Sprite();
		addChild(sprite);
		g = sprite.graphics;
		g.lineStyle(1, COLOR, ALPHA);
		originalBMD = Assets.getBitmapData(ASSET);
		WIDTH = originalBMD.width;
		HEIGHT = originalBMD.height + 80;

		//  VERSION
		var versionTF = getTextField("hxGeomAlgo v" + Version.toString(), 0, 0);
		versionTF.autoSize = TextFieldAutoSize.LEFT;
		versionTF.y = stage.stageHeight - 17;
		addChild(versionTF);
		
		// ORIGINAL IMAGE
		updateXY(0, 0);
		addChildAt(originalBitmap = new Bitmap(originalBMD), 0);	// add it underneath sprite
		originalBitmap.x = X;
		originalBitmap.y = Y;
		addChild(getTextField("Original\n" + originalBMD.width + "x" + originalBMD.height, X, Y));

		// MARCHING SQUARES
		updateXY(0, 1);
		//clipRect = new Rectangle(10, 20, 90, 65);
		clipRect = originalBMD.rect;
		marchingSquares = new MarchingSquares(originalBMD, 1, clipRect);
		perimeter = marchingSquares.march();
		drawPerimeter(perimeter, X + clipRect.x, Y + clipRect.y);
		addChild(getTextField("MarchSqrs\n" + perimeter.length + " pts", X, Y));

		// RAMER-DOUGLAS-PEUCKER SIMPLIFICATION
		updateXY(0, 2);
		simplifiedPolyRDP = RamerDouglasPeucker.simplify(perimeter, 1.5);
		drawPoly(simplifiedPolyRDP, X + clipRect.x, Y + clipRect.y);
		addChild(getTextField("Doug-Peuck\n" + simplifiedPolyRDP.length + " pts", X, Y));

		// VISVALINGAM-WHYATT SIMPLIFICATION
		updateXY(0, 3);
		var simplifiedPolyVW = VisvalingamWhyatt.simplify(perimeter, SimplificationMethod.MaxPoints(simplifiedPolyRDP.length));
		drawPoly(simplifiedPolyVW, X + clipRect.x, Y + clipRect.y);
		addChild(getTextField("Visv-Whyatt\n" + simplifiedPolyVW.length + " pts", X, Y));		
		
		// EARCLIPPER TRIANGULATION
		updateXY(0, 4);
		triangulation = EarClipper.triangulate(simplifiedPolyRDP);
		drawTriangulation(triangulation, X + clipRect.x, Y + clipRect.y);
		addChild(getTextField("EC-Triang\n" + triangulation.length + " tris", X, Y));

		// CONNECTED COMPONENTS LABELING
		updateXY(1, 0);
		var labeler = new CustomLabeler(originalBMD, 1, true, Connectivity.EIGHT_CONNECTED, clipRect);
		labeler.run();
		labelBMP = new Bitmap(labeler.labelMap);
		addChildAt(labelBMP, 0);
		labelBMP.x = X + clipRect.x;
		labelBMP.y = Y + clipRect.y;
		for (contour in labeler.contours) {
			var isHole = PolyTools.isCCW(contour);
			var color:UInt = isHole ? 0xFF00FF00 : 0xFF0000FF;
			
			for (p in contour) {
				labeler.labelMap.setPixel32(Std.int(p.x), Std.int(p.y), color);
			}
		}
		addChild(getTextField("CCLabeler\n" + labeler.numComponents + " cmpts\n" + labeler.contours.length + " cntrs", X, Y));

		// EARCLIPPER DECOMPOSITION
		updateXY(1, 1);
		decomposition = EarClipper.polygonizeTriangles(triangulation);
		drawDecomposition(decomposition, X + clipRect.x, Y + clipRect.y);
		addChild(getTextField("EarClipper\nDecomp\n" + decomposition.length + " polys", X, Y));

		// BAYAZIT DECOMPOSITION
		updateXY(1, 2);
		decomposition = Bayazit.decomposePoly(simplifiedPolyRDP);
		drawDecompositionBayazit(decomposition, X + clipRect.x, Y + clipRect.y);
		addChild(getTextField("Bayazit\nDecomp\n" + decomposition.length + " polys", X, Y));

		// SNOEYINK-KEIL DECOMPOSITION
		updateXY(1, 3);
		decomposition = SnoeyinkKeil.decomposePoly(simplifiedPolyRDP);
		drawDecomposition(decomposition, X + clipRect.x, Y + clipRect.y);
		addChild(getTextField("Snoeyink-Keil\nMin Decomp\n" + decomposition.length + " polys", X, Y));
		
		// VISIBILITY
		updateXY(1, 4);
		drawPoly(simplifiedPolyRDP, X + clipRect.x, Y + clipRect.y);
		var origIdx = Std.int(Math.random() * simplifiedPolyRDP.length);
		var origPoint = simplifiedPolyRDP[origIdx];
		// visible points
		var visPoints = Visibility.getVisiblePolyFrom(simplifiedPolyRDP, origIdx);
		g.lineStyle(1, 0xFFFF00);
		drawPoly(visPoints, X + clipRect.x, Y + clipRect.y);
		// visible vertices
		var visIndices = Visibility.getVisibleIndicesFrom(simplifiedPolyRDP, origIdx);
		var visVertices = [for (i in 0...visIndices.length) simplifiedPolyRDP[visIndices[i]]];
		g.lineStyle(1, 0x00FF00);
		drawPoints(visVertices, X + clipRect.x, Y + clipRect.y);
		// draw origPoint
		g.lineStyle(1, 0x0000FF);
		if (origPoint != null) g.drawCircle(X + origPoint.x + clipRect.x, Y + origPoint.y + clipRect.y, 3);
		addChild(getTextField("Visibility\n" + visVertices.length + " vts\n" + visPoints.length + " pts", X, Y));
		g.lineStyle(1, COLOR, ALPHA);

		// TESS2 - TRIANGULATION
		updateXY(0, 5);
		var polySize = 3;
		var resultType = ResultType.POLYGONS;
		var flatContours = [for (c in labeler.contours) PolyTools.toFlatArray(RamerDouglasPeucker.simplify(c, 1.5))];
		var res = Tess2.tesselate(flatContours, null, resultType, polySize);
		var polys = Tess2.convertResult(res.vertices, res.elements, resultType, polySize);
		for (p in polys) drawPoly(p, X + clipRect.x, Y + clipRect.y, false);
		addChild(getTextField("Tess2-Triang\n" + res.elementCount + " tris", X, Y));

		// TESS2 + EC - DECOMP
		/*
		updateXY(1, 6);
		var polygonized = EarClipper.polygonizeTriangles(polys);
		for (p in polygonized) drawPoly(p, X + clipRect.x, Y + clipRect.y, false);
		addChild(getTextField("Tess2 + EC\nDecomp\n" + polygonized.length + " polys", X, Y));
		*/

		// TESS2 - DECOMP
		updateXY(1, 5);
		polySize = 24;
		resultType = ResultType.POLYGONS;
		res = Tess2.tesselate(flatContours, null, resultType, polySize);
		polys = Tess2.convertResult(res.vertices, res.elements, resultType, polySize);
		for (p in polys) drawPoly(p, X + clipRect.x, Y + clipRect.y, false);
		addChild(getTextField("Tess2\nDecomp\n" + res.elementCount + " polys", X, Y));
		
		// TESS2 - CONTOURS
		/*
		updateXY(1, 7);
		resultType = ResultType.BOUNDARY_CONTOURS;
		res = Tess2.tesselate(flatContours, null, resultType, polySize);
		polys = Tess2.convertResult(res.vertices, res.elements, resultType, polySize);
		for (p in polys) drawPoly(p, X + clipRect.x, Y + clipRect.y, false);
		addChild(getTextField("Tess2\nContours\n" + res.elementCount + " polys", X, Y));
		*/
	
		//stage.addChild(new FPS(5, 5, 0xFFFFFF));
		stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);

		dumpPoly(simplifiedPolyRDP, false);
	}
	
	static public function savePNG(bmd:BitmapData, fileName:String) {
	#if (neko)
		var ba:ByteArray = bmd.encode("png", 1);
		var file:FileOutput = sys.io.File.write(fileName, true);
		file.writeString(ba.toString());
		file.close();
	#end
	}
	
	public function updateXY(row:Int, col:Int):Void 
	{
		X = START_POINT.x + (WIDTH + X_GAP) * col;
		Y = START_POINT.y + (HEIGHT + Y_GAP) * row;
	}
	
	public function dumpPoly(poly:Array<HxPoint>, reverse:Bool = false):Void {
		var len = poly.length;
		var str = "poly dump: ";
		for (i in 0...len) {
			var p = poly[reverse ? len - i - 1 : i];
			str += p.x + "," + p.y + ",";
		}
		trace(str);
	}

	public function drawPerimeter(points:Array<HxPoint>, x:Float, y:Float):Void 
	{
		// draw clipRect
		g.drawRect(originalBitmap.x + clipRect.x, originalBitmap.y + clipRect.y, clipRect.width, clipRect.height);

		drawPoly(points, x, y, false);
	}

	public function drawPoints(points:Array<HxPoint>, x:Float, y:Float, radius:Float = 2):Void 
	{
		for (i in 0...points.length) {
			var p = points[i];
			g.drawCircle(x + p.x, y + p.y, radius);
		}
	}
	
	public function drawPointsLabels(points:Array<HxPoint>, x:Float, y:Float):Void 
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
	
	public function drawPoly(points:Array<HxPoint>, x:Float, y:Float, showPoints:Bool = true, showLabels:Bool = false):Void 
	{
		if (points.length <= 0) return;
		
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
			quit();
		}
	}
	
	public function quit():Void 
	{
		#if (flash || html5)
			System.exit(1);
		#else
			Sys.exit(1);
		#end
	}
}


class CustomLabeler extends CCLabeler 
{
	
	public function new(bmd:BitmapData, alphaThreshold:Int = 1, traceContours:Bool = true, connectivity:Connectivity = Connectivity.EIGHT_CONNECTED, clipRect:Rectangle = null, calcArea:Bool = false)
	{
		super(bmd, alphaThreshold, traceContours, connectivity, clipRect, calcArea);
	}
	
	override function isPixelSolid(x:Int, y:Int):Bool 
	{
		var pixelColor:UInt = getPixel(sourceVector, x, y, 0);
		
		var pixel = getPixelInfo(pixelColor);
		return (pixel.a > 0);
	}
	
	static inline public function getPixelInfo(color:UInt):{a:Int, r:Int, g:Int, b:Int, h:Float, s:Float, v:Float, l:Float}
	{
		var a:Int = (color >> 24) & 0xFF;
		var colMask:Int = a > 0 ? 0xFF : 0;	// fix to force neko to report rgb as 0 when alpha is 0 (to be consistent with flash)
		var r:Int = (color >> 16) & colMask;
		var g:Int = (color >> 8) & colMask;
		var b:Int = color & colMask;

		var info:Dynamic = {a:a, r:r, g:g, b:b};
		
		// hue
		var max:Int = Std.int(Math.max(r, Math.max(g, b)));
		var min:Int = Std.int(Math.min(r, Math.min(g, b)));

		if (max == min) info.h = 0;
		else if (max == r) info.h = (60 * (g - b) / (max - min) + 360) % 360;
		else if (max == g) info.h = (60 * (b - r) / (max - min) + 120);
		else if (max == b) info.h = (60 * (r - g) / (max - min) + 240);

		info.h /= 360;
		
		// saturation
		if (max == 0) info.s = 0;
		else info.s = (max - min) / max;
		
		// value
		info.v = max / 255;
		
		// luminance
		info.l = (0.2126 * r / 255 + 0.7152 * g / 255 + 0.0722 * b / 255);
		
		return info;
	}
}