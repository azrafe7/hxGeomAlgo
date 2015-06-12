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
import flash.utils.ByteArray;
import flash.text.TextFieldAutoSize;

import haxe.Resource;
import haxe.Timer;

import hxPixels.Pixels;

import hxGeomAlgo.Version;
import hxGeomAlgo.EarClipper;
import hxGeomAlgo.HxPoint;
import hxGeomAlgo.MarchingSquares;
import hxGeomAlgo.IsoContours;
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

#if (neko)
import sys.io.File;
import sys.io.FileOutput;
#end


class GeomAlgoTest extends Sprite {

	private var g:Graphics;
	
	private var COLOR:Int = 0xFF0000;
	private var ALPHA:Float = 1.;
	private var X_GAP:Int = 10;
	private var Y_GAP:Int = 25;

	private var TEXT_COLOR:Int = 0xFFFFFF;
	private var TEXT_FONT:String = "_typewriter";
	private var TEXT_SIZE:Float = 12;
	private var TEXT_OFFSET:Float = -60;
	private var TEXT_OUTLINE:GlowFilter = new GlowFilter(0xFF000000, 1, 2, 2, 6);

	private var START_POINT:HxPoint = new HxPoint(20, 90);

	var X:Float;
	var Y:Float;
	var WIDTH:Int;
	var HEIGHT:Int;

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
	
	public function new(asset:String) {
		super();

		var sprite = new Sprite();
		addChild(sprite);
		g = sprite.graphics;
		g.lineStyle(.5, COLOR, ALPHA);
		originalBMD = openfl.Assets.getBitmapData(asset);
		WIDTH = originalBMD.width;
		HEIGHT = originalBMD.height + 80;

		//  ASSET IMAGE
		var assetTF = getTextField("move: ARROWS/GHJY  |  cycle: CTRL+ARROWS  |  zoom: +/-  |  [" + asset + "]", 0, 5 * TEXT_SIZE);
		trace("\n\n[" + asset + "]\n");
		assetTF.autoSize = TextFieldAutoSize.LEFT;
		addChild(assetTF);

		//  VERSION
		var versionTF = getTextField("hxGeomAlgo v" + Version.toString(), 0, 0);
		versionTF.autoSize = TextFieldAutoSize.LEFT;
		versionTF.y = flash.Lib.current.stage.stageHeight - 17;
		addChild(versionTF);
		
		// ORIGINAL IMAGE
		setSlot(0, 0);
		addChildAt(originalBitmap = new Bitmap(originalBMD), 0);	// add it underneath sprite
		originalBitmap.x = X;
		originalBitmap.y = Y;
		clipRect = originalBMD.rect;
		//g.drawRect(originalBitmap.x + clipRect.x, originalBitmap.y + clipRect.y, clipRect.width, clipRect.height);
		addChild(getTextField("Original\n" + originalBMD.width + "x" + originalBMD.height, X, Y));

		// MARCHING SQUARES
		setSlot(0, 1);
		var startTime = Timer.stamp();
		marchingSquares = new MarchingSquares(originalBMD, 1);
		trace("ms startPoint: " + marchingSquares.findStartPoint());
		perimeter = marchingSquares.march();
		trace('MarchSqrs     : ${Timer.stamp() - startTime}');
		drawPoly(perimeter, X + clipRect.x, Y + clipRect.y, false);
		// draw perimeter pixels: in green if on solid pixels, in blue if not
		var perimeterBitmap = new Bitmap(new BitmapData(WIDTH, HEIGHT, true, 0));
		for (p in perimeter) {
			var isSolid = @:privateAccess marchingSquares.isPixelSolid(Std.int(p.x), Std.int(p.y));
			//perimeterBitmap.bitmapData.setPixel32(Std.int(p.x), Std.int(p.y), isSolid ? 0xFF0000FF : 0xFF00FF00);
		}
		perimeterBitmap.x = originalBitmap.x;
		perimeterBitmap.y = originalBitmap.y;
		addChild(perimeterBitmap);
		addChild(getTextField("MarchSqrs\n" + perimeter.length + " pts", X, Y));

		setSlot(0, 0);
		startTime = Timer.stamp();
		
		var ms2 = new IsoContours(originalBMD);
		
		var redIso = function(pixels, x, y) {
			if (IsoContours.isOutOfBounds(pixels, x, y)) return 0;
			else return ((pixels.getPixel32(x, y) >>> 24) & 0xFF);
		}
		
		ms2.isoFunction = redIso;
		var cnts = ms2.find(0x0, false);
		//cnts = cnts.concat(ms2.find(0x80, false, false));
		trace('MarchSqrs2    : ${Timer.stamp() - startTime}');
		/*g.lineStyle(1, 0x0000ff);
		var nf = cnts[1];
		while (nf.length > 0) {
			var p = nf.pop();
			g.moveTo((X + p.x), (Y + p.y));
			g.drawCircle((X + p.x), (Y + p.y), 1.5);
			//g.lineTo((X + p.x + .1), (Y + p.y + .1));
		}*/
		for (isoLine in cnts) {
			trace("isoDups: " + PolyTools.findDuplicatePoints(isoLine));
			g.lineStyle(.5, Std.random(0xFFFFFF));
			drawPoly(isoLine, X, Y, false);
			
			if (isoLine.length > 1) {
				// first segment
				g.lineStyle(1, 0xFF0000, .6);
				g.moveTo(isoLine[0].x + X, isoLine[0].y + Y);
				g.lineTo(isoLine[1].x + X, isoLine[1].y + Y);
			}
		}
		/*for (points in cnts) {
			trace(PolyTools.findDuplicatePoints(points));
			for (i in 0...points.length-1) {
				g.lineStyle(.5, Std.random(0xffffff));
				var p = points[i];
				var q = points[i+1];
				g.moveTo((X + p.x), (Y + p.y));
				g.lineTo((X + q.x), (Y + q.y));
				var t = .75;
				var dx = q.x - p.x;
				var dy = q.y - p.y;
				if (p.equals(q)) {
					g.drawCircle((X + p.x), (Y + p.y), .5);
				}
				//g.drawCircle(p.x + dx * t + X, p.y + dy * t + Y, .2);
			    // arrow head
				drawArrowHead(p, q, X, Y, .5, 20);
			}
		}*/
		trace("cnts: " + cnts.length);
		//drawPaths(cnts, X, Y, false);
		
		// RAMER-DOUGLAS-PEUCKER SIMPLIFICATION
		setSlot(0, 2);
		startTime = Timer.stamp();
		simplifiedPolyRDP = RamerDouglasPeucker.simplify(perimeter, 1.5);
		trace('Doug-Peuck    : ${Timer.stamp() - startTime}');
		drawPoly(simplifiedPolyRDP, X + clipRect.x, Y + clipRect.y);
		addChild(getTextField("Doug-Peuck\n" + simplifiedPolyRDP.length + " pts", X, Y));
		
		// VISVALINGAM-WHYATT SIMPLIFICATION
		setSlot(0, 3);
		startTime = Timer.stamp();
		var simplifiedPolyVW = VisvalingamWhyatt.simplify(perimeter, SimplificationMethod.MaxPoints(simplifiedPolyRDP.length));
		trace('Visv-Whyatt   : ${Timer.stamp() - startTime}');
		drawPoly(simplifiedPolyVW, X + clipRect.x, Y + clipRect.y);
		addChild(getTextField("Visv-Whyatt\n" + simplifiedPolyVW.length + " pts", X, Y));		
		
		// EARCLIPPER TRIANGULATION
		setSlot(0, 4);
		startTime = Timer.stamp();
		triangulation = EarClipper.triangulate(simplifiedPolyRDP);
		trace('ECTriang      : ${Timer.stamp() - startTime}');
		trace(testOrientation(triangulation), testSimple(triangulation), testConvex(triangulation));
		drawTriangulation(triangulation, X + clipRect.x, Y + clipRect.y);
		addChild(getTextField("EC-Triang\n" + triangulation.length + " tris", X, Y));

		// CONNECTED COMPONENTS LABELING
		setSlot(1, 0);
		startTime = Timer.stamp();
		var labeler = new CustomLabeler(originalBMD, 1, true, Connectivity.EIGHT_CONNECTED, true);
		labeler.run();
		trace('CCLabeler     : ${Timer.stamp() - startTime}');
		labelBMP = new Bitmap(new BitmapData(labeler.labelMap.width, labeler.labelMap.height, true, 0));
		addChildAt(labelBMP, 0);
		labelBMP.x = X + clipRect.x;
		labelBMP.y = Y + clipRect.y;
		for (contour in labeler.contours) {
			var isHole = PolyTools.isCCW(contour);
			var color:Int = isHole ? 0xFF00FF00 : 0xFF0000FF;
			
			for (p in contour) {
				labeler.labelMap.setPixel32(Std.int(p.x), Std.int(p.y), color);
			}
		}
		labeler.labelMap.applyToBitmapData(labelBMP.bitmapData);
		addChild(getTextField("CCLabeler\n" + labeler.numComponents + " cmpts\n" + labeler.contours.length + " cntrs", X, Y));

		// EARCLIPPER DECOMPOSITION
		setSlot(1, 1);
		startTime = Timer.stamp();
		decomposition = EarClipper.polygonizeTriangles(triangulation);
		trace('ECDecomp      : ${Timer.stamp() - startTime}');
		trace(testOrientation(decomposition), testSimple(decomposition), testConvex(decomposition));
		drawDecomposition(decomposition, X + clipRect.x, Y + clipRect.y);
		addChild(getTextField("EarClipper\nDecomp\n" + decomposition.length + " polys", X, Y));

		// BAYAZIT DECOMPOSITION
		setSlot(1, 2);
		startTime = Timer.stamp();
		decomposition = Bayazit.decomposePoly(simplifiedPolyRDP);
		trace('BayazDecomp   : ${Timer.stamp() - startTime}');
		trace(testOrientation(decomposition), testSimple(decomposition), testConvex(decomposition));
		drawDecompositionBayazit(decomposition, X + clipRect.x, Y + clipRect.y);
		addChild(getTextField("Bayazit\nDecomp\n" + decomposition.length + " polys", X, Y));

		// SNOEYINK-KEIL DECOMPOSITION
		setSlot(1, 3);
		startTime = Timer.stamp();
		decomposition = SnoeyinkKeil.decomposePoly(simplifiedPolyRDP);
		trace('SnoeKeilDecomp: ${Timer.stamp() - startTime}');
		trace(testOrientation(decomposition), testSimple(decomposition), testConvex(decomposition));
		drawDecomposition(decomposition, X + clipRect.x, Y + clipRect.y);
		addChild(getTextField("Snoeyink-Keil\nMin Decomp\n" + decomposition.length + " polys", X, Y));
		
		// VISIBILITY
		setSlot(1, 4);
		drawPoly(simplifiedPolyRDP, X + clipRect.x, Y + clipRect.y);
		var origIdx = Std.int(Math.random() * simplifiedPolyRDP.length);
		var origPoint = simplifiedPolyRDP[origIdx];
		// visible points
		startTime = Timer.stamp();
		var visPoints = Visibility.getVisiblePolyFrom(simplifiedPolyRDP, origIdx);
		g.lineStyle(1, 0xFFFF00);
		drawPoly(visPoints, X + clipRect.x, Y + clipRect.y);
		// visible vertices
		var visIndices = Visibility.getVisibleIndicesFrom(simplifiedPolyRDP, origIdx);
		var visVertices = [for (i in 0...visIndices.length) simplifiedPolyRDP[visIndices[i]]];
		trace('Visisibility  : ${Timer.stamp() - startTime}');
		g.lineStyle(1, 0x00FF00);
		drawPoints(visVertices, X + clipRect.x, Y + clipRect.y);
		// draw origPoint
		g.lineStyle(1, 0x0000FF);
		if (origPoint != null) g.drawCircle(X + origPoint.x + clipRect.x, Y + origPoint.y + clipRect.y, 3);
		addChild(getTextField("Visibility\n" + visVertices.length + " vts\n" + visPoints.length + " pts", X, Y));
		g.lineStyle(1, COLOR, ALPHA);

		// TESS2 - TRIANGULATION
		setSlot(0, 5);
		var polySize = 3;
		var resultType = ResultType.POLYGONS;
		var flatContours = [for (c in labeler.contours) PolyTools.toFloatArray(RamerDouglasPeucker.simplify(c, 1.))];
		startTime = Timer.stamp();
		var res = Tess2.tesselate(flatContours, null, resultType, polySize);
		var polys = Tess2.convertResult(res.vertices, res.elements, resultType, polySize);
		trace('Tess2Triang   : ${Timer.stamp() - startTime}');
		trace(testOrientation(polys), testSimple(polys), testConvex(polys));
		for (p in polys) drawPoly(p, X + clipRect.x, Y + clipRect.y, false);
		addChild(getTextField("Tess2-Triang\n" + res.elementCount + " tris", X, Y));

		// TESS2 + EC - DECOMP
		/*
		setSlot(1, 6);
		var polygonized = EarClipper.polygonizeTriangles(polys);
		for (p in polygonized) drawPoly(p, X + clipRect.x, Y + clipRect.y, false);
		addChild(getTextField("Tess2 + EC\nDecomp\n" + polygonized.length + " polys", X, Y));
		*/

		// TESS2 - DECOMP
		setSlot(1, 5);
		polySize = 24;
		resultType = ResultType.POLYGONS;
		startTime = Timer.stamp();
		res = Tess2.tesselate(flatContours, null, resultType, polySize);
		polys = Tess2.convertResult(res.vertices, res.elements, resultType, polySize);
		trace('Tess2Decomp   : ${Timer.stamp() - startTime}');
		trace(testOrientation(polys), testSimple(polys), testConvex(polys));
		for (p in polys) drawPoly(p, X + clipRect.x, Y + clipRect.y, false);
		addChild(getTextField("Tess2\nDecomp\n" + res.elementCount + " polys", X, Y));
		
		// TESS2 - CONTOURS
		/*
		setSlot(1, 7);
		resultType = ResultType.BOUNDARY_CONTOURS;
		res = Tess2.tesselate(flatContours, null, resultType, polySize);
		polys = Tess2.convertResult(res.vertices, res.elements, resultType, polySize);
		for (p in polys) drawPoly(p, X + clipRect.x, Y + clipRect.y, false);
		addChild(getTextField("Tess2\nContours\n" + res.elementCount + " polys", X, Y));
		*/
	
		// setup a ring poly to test Tess2 bool ops
		var radius = originalBMD.width / 2;
		var holeRadius = radius - 25;
		var outerCircle = [];
		var innerCircle = [];
		var cx = originalBMD.width / 2;
		var cy = originalBMD.height / 2;
		var theta = 0.;
		var delta = 2 * Math.PI / 100;
		for (i in 0...100) {
			var cos = Math.cos(theta);
			var sin = Math.sin(theta);
			outerCircle.push(new HxPoint(cx + cos * radius, cy + sin * radius));
			innerCircle.push(new HxPoint(cx + cos * holeRadius, cy + sin * holeRadius));
			theta += delta;
		}
		var flatRing = [PolyTools.toFloatArray(outerCircle), PolyTools.reverseFloatArray(PolyTools.toFloatArray(innerCircle))];
		
		polySize = 3;
		resultType = ResultType.BOUNDARY_CONTOURS;

		// TESS2 - UNION
		setSlot(2, 1);
		startTime = Timer.stamp();
		res = Tess2.union(flatContours, flatRing, resultType, polySize, 2);
		polys = Tess2.convertResult(res.vertices, res.elements, resultType, polySize);
		trace('Tess2Union    : ${Timer.stamp() - startTime}');
		drawPaths(polys, X + clipRect.x, Y + clipRect.y, true);
		addChild(getTextField("Tess2\nUnion\n" + res.elementCount + " polys", X, Y));
		
		// TESS2 - INTERSECTION
		setSlot(2, 2);
		startTime = Timer.stamp();
		res = Tess2.intersection(flatContours, flatRing, resultType, polySize, 2);
		polys = Tess2.convertResult(res.vertices, res.elements, resultType, polySize);
		trace('Tess2Intersect: ${Timer.stamp() - startTime}');
		drawPaths(polys, X + clipRect.x, Y + clipRect.y, true);
		addChild(getTextField("Tess2\nIntersection\n" + res.elementCount + " polys", X, Y));
		
		// TESS2 - DIFFERENCE
		setSlot(2, 3);
		startTime = Timer.stamp();
		res = Tess2.difference(flatContours, flatRing, resultType, polySize, 2);
		polys = Tess2.convertResult(res.vertices, res.elements, resultType, polySize);
		trace('Tess2Diff     : ${Timer.stamp() - startTime}');
		drawPaths(polys, X + clipRect.x, Y + clipRect.y, true);
		addChild(getTextField("Tess2\nDifference\n" + res.elementCount + " polys", X, Y));
		
		//flash.Lib.current.stage.addChild(new openfl.FPS(5, 5, 0xFFFFFF));

		dumpPoly(simplifiedPolyRDP, false);
		
		// Tess2.js parsable poly string (https://dl.dropboxusercontent.com/u/32864004/dev/FPDemo/tess2.js-demo/index.html)
		/*var str = "";
		for (poly in flatContours) {
			for (i in 0...poly.length >> 1) {
				str += '${poly[i * 2]} ${poly[i * 2 + 1]}\n';
			}
			str += "\n";
		}
		trace(str);*/
		
		// test CCW and duplicate points
		trace("\n");
		var simplifications = [perimeter, simplifiedPolyRDP, simplifiedPolyVW, visPoints].concat(labeler.contours);
		var labelerHeaders = [for (i in 0...labeler.contours.length) 'labeler[$i]   '];
		var headers = ["perimeter    ", "simplifiedRDP", "simplifiedVW ", "visPoints    "].concat(labelerHeaders);
		for (i in 0...simplifications.length) {
			var poly = simplifications[i];
			var name = headers[i];
			var orientation = testOrientation([poly]);
			var hasDups = PolyTools.findDuplicatePoints(poly).length > 0;
			trace('$name (orientation:$orientation, hasDups:$hasDups)');
		}
	}
	
	static public function testOrientation(polys:Array<Poly>):String {
		var res = "none";
		
		for (i in 0...polys.length) {
			var poly = polys[i];
			var orientation = PolyTools.isCCW(poly) ? "CCW" : "CW";
			
			if (i == 0) {
				res = orientation;
			} else if (res != orientation) {
				res = "mixed";
				break;
			}
		}
		
		return res;
	}
	
	static public function testConvex(polys:Array<Poly>):String {
		var res = "none";
		
		for (i in 0...polys.length) {
			var poly = polys[i];
			var convex = PolyTools.isConvex(poly) ? "convex" : "not convex";
			
			if (i == 0) {
				res = convex;
			} else if (res != convex) {
				res = "mixed";
				break;
			}
		}
		
		return res;
	}
	
	static public function testSimple(polys:Array<Poly>):String {
		var res = "none";
		
		for (i in 0...polys.length) {
			var poly = polys[i];
			var convex = PolyTools.isSimple(poly) ? "simple" : "not simple";
			
			if (i == 0) {
				res = convex;
			} else if (res != convex) {
				res = "mixed";
				break;
			}
		}
		
		return res;
	}
	
	static public function savePNG(bmd:BitmapData, fileName:String) {
	#if (sys)
		var ba:ByteArray = bmd.encode("png", 1);
		var file:FileOutput = sys.io.File.write(fileName, true);
		file.writeString(ba.toString());
		file.close();
	#end
	}
	
	public function setSlot(row:Int, col:Int):Void 
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

	public function drawPoints(points:Array<HxPoint>, x:Float, y:Float, radius:Float = 2):Void 
	{
		for (i in 0...points.length) {
			var p = points[i];
			g.drawCircle(x + p.x, y + p.y, radius);
		}
	}
	
	// Draw arrow head at `q`
	public function drawArrowHead(p:HxPoint, q:HxPoint, x:Float, y:Float, factor:Float = 2.5, angleDeg:Float = 30):Void 
	{
		var dx = p.x - q.x;
		var dy = p.y - q.y;
		var l = Math.sqrt(dx * dx + dy * dy) * factor;
		var cos = Math.cos(Math.PI * angleDeg / 180);
		var sin = Math.sin(Math.PI * angleDeg / 180);
		dx = dx / l;
		dy = dy / l;
		var end1 = new HxPoint(q.x + (dx * cos + dy * -sin), q.y + (dx * sin + dy * cos));
		var end2 = new HxPoint(q.x + (dx * cos + dy * sin), q.y + (dx * -sin + dy * cos));
		g.moveTo(end1.x + x, end1.y + y);
		g.lineTo((X + q.x), (Y + q.y));
		g.lineTo(end2.x + x, end2.y + y);
		//g.lineTo(end1.x + x, end1.y + y); // close head
		g.moveTo((X + q.x), (Y + q.y));
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
	
	public function drawPoly(points:Array<HxPoint>, x:Float, y:Float, showPoints:Bool = true, showLabels:Bool = false, fill:Bool = false):Void 
	{
		if (points.length <= 0) return;
		
		// points
		if (showPoints) drawPoints(points, x, y);
		
		// lines
		if (fill) g.beginFill(COLOR, .5);
		g.moveTo(x + points[0].x, y + points[0].y);
		for (i in 1...points.length) {
			var p = points[i];
			g.lineTo(x + p.x, y + p.y);
			drawArrowHead(points[i - 1], p, x, y, 2.25);
		}
		g.lineTo(x + points[0].x, y + points[0].y);
		if (fill) g.endFill();
		
		// labels
		if (showLabels) drawPointsLabels(points, x, y);
	}

	public function drawPaths(paths:Array<Array<HxPoint>>, x:Float, y:Float, fill:Bool = false):Void 
	{
		if (paths.length <= 0) return;
		
		var data = new flash.Vector();
		var commands = new flash.Vector();

		for (path in paths) {
			var len = path.length;
			
			for (i in 0...len) {
				if (i == 0) commands.push(1); // moveTo
				else commands.push(2); // lineTo
				
				data.push(x + path[i].x);
				data.push(y + path[i].y);
			}
			// close
			if (fill) {
				commands.push(2);
				data.push(x + path[0].x);
				data.push(y + path[0].y);
			}
		}
		
		if (fill) g.beginFill(COLOR, .5);
		g.drawPath(commands, data, flash.display.GraphicsPathWinding.EVEN_ODD);
		if (fill) g.endFill();
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
}

typedef PixelInfo = {
	var a:Int;
	var r:Int;
	var g:Int;
	var b:Int;
	var h:Float;
	var s:Float;
	var v:Float;
	var l:Float;
}

class CustomLabeler extends CCLabeler 
{
	var pixelInfoMap:Map<Int, PixelInfo>; // cache
	
	public function new(pixels:Pixels, alphaThreshold:Int = 1, traceContours:Bool = true, connectivity:Connectivity = Connectivity.EIGHT_CONNECTED, calcArea:Bool = false)
	{
		super(pixels, alphaThreshold, traceContours, connectivity, calcArea);
		
		pixelInfoMap = new Map();
	}
	
	override function isPixelSolid(x:Int, y:Int):Bool 
	{
		var pixelColor:Int = getPixel32(sourcePixels, x, y, 0);
		
		var pixelInfo = getPixelInfo(pixelColor);
		
		return (pixelInfo.a > 0); // this could have been more complex (e.g. ` && pixelInfo.h > .5 && pixelInfo.h < .8`)
	}
	
	public function getPixelInfo(color:Int):PixelInfo
	{
		if (pixelInfoMap[color] != null) return pixelInfoMap[color];
		
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
		//info.l = (0.2126 * r / 255 + 0.7152 * g / 255 + 0.0722 * b / 255);
		info.l = (0.33333 * r / 255 + 0.33333 * g / 255 + 0.33333 * b / 255);
		
		pixelInfoMap[color] = info;
		
		return info;
	}
}