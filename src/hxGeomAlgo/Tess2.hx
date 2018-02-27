/*
 * SGI FREE SOFTWARE LICENSE B (Version 2.0, Sept. 18, 2008) 
 * Copyright (C) [dates of first publication] Silicon Graphics, Inc.
 * All Rights Reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
 * of the Software, and to permit persons to whom the Software is furnished to do so,
 * subject to the following conditions:
 * 
 * The above copyright notice including the dates of first publication and either this
 * permission notice or a reference to http://oss.sgi.com/projects/FreeB/ shall be
 * included in all copies or substantial portions of the Software. 
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
 * INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
 * PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL SILICON GRAPHICS, INC.
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
 * OR OTHER DEALINGS IN THE SOFTWARE.
 * 
 * Except as contained in this notice, the name of Silicon Graphics, Inc. shall not
 * be used in advertising or otherwise to promote the sale, use or other dealings in
 * this Software without prior written authorization from Silicon Graphics, Inc.
 */

/**
 * Tesselator implementation.
 * 
 * From https://github.com/memononen/tess2.js readme:
 *
 * "The tess2.js library performs polygon boolean operations and tesselation to triangles 
 * and convex polygons. It is a port of libtess2, which in turn is a cleaned up version 
 * of the stock GLU tesselator. The original code was written by Eric Veach in 1994. 
 * The greatest thing about tess2.js is that it handles all kinds of input like 
 * self-intersecting polygons or any number of holes and contours."
 * 
 * Based on:
 * 
 * @see tess2.js (https://github.com/memononen/tess2.js) 			(JS - by Mikko Mononen, Aug 2013)
 * @see libtess2 PR (https://github.com/memononen/libtess2/pull/7)	(C - by Marius Kintel)
 * GLU libtess 														(by Eric Veach, July 1994)
 * 
 * @author azrafe7
 */

package hxGeomAlgo;

import hxGeomAlgo.PolyTools.Poly;
import hxGeomAlgo.Debug;


@:expose
enum WindingRule
{
  ODD;
  NON_ZERO;
  POSITIVE;
  NEGATIVE;
  ABS_GEQ_TWO;
}

@:expose
enum ResultType
{
  POLYGONS;
  CONNECTED_POLYGONS;
  BOUNDARY_CONTOURS;
  EXPERIMENTAL_DELAUNAY; /* Similar to POLYGONS, but we output only triangles and we attempt 
                to provide a valid Constrained Delaunay triangulation.
                @see https://github.com/memononen/libtess2/pull/7
              */
}

typedef TessResult = {
  var vertices:Array<Float>;
  var vertexIndices:Array<Int>;
  var vertexCount:Int;
  var elements:Array<Int>;
  var elementCount:Int;
}

/**
 * Class offering a quick wrapper around Tesselator functions.
 * 
 * For more info about how to use this class see the demo by Mikko Mononen on (https://github.com/memononen/tess2.js).
 * Live version rehosted here (https://dl.dropboxusercontent.com/u/32864004/dev/FPDemo/tess2.js-demo/index.html).
 * 
 * Further reading: http://www.glprogramming.com/red/chapter11.html
 */
@:expose
class Tess2
{
#if js
  static function __init__() {
    PolyTools.exposeEnum(WindingRule);
    PolyTools.exposeEnum(ResultType);
  }
#end
  
  /**
   * Tesselates the specified `contours`.
   * 
   * (see Tess2.convertResult() for an easy way to use the returned TessResult)
   * 
   * @param	contours		Array of polygons to tesselate. Each poly is specified as a sequence of point coords (i.e. [x0, y0, x1, y1, x2, y2, ...]).
   * @param	windingRule		Winding rule to apply. Deaults to WindingRule.ODD.
   * @param	resultType		The result type you want as output. Defaults to ResultType.POLYGONS.
   * @param	polySize		Max dimesion of the polygons resulting from the tesselation. Defaults to 3 (not considered if resultType is BOUNDARY_CONTOURS or EXPERIMENTAL_DELAUNAY).
   * @param	vertexDim		Pass 2 when working with 2D polys (default), or 3 for 3D.
   * @param	normal			Array of length 3 representing the normals in each plane.
   * 
   * @return A structure of TessResult type, composed of the following fields:
   *		   { 
   *				vertices:Array<Float>;		// A sequence of point coords in the same format of `contours`.
   *				vertexIndices:Array<Int>;	// A sequence of indices that map into the original `contours` joined together.
   *				vertexCount:Int;			// The number of vertices.
   *				elements:Array<Int>;		// Elements' indices whose meaning depends on the ResultType used.
   *				elementCount:Int;			// The number of elements found.
   * 		   };
   */
  static public function tesselate(contours:Array<Array<Float>>, windingRule:WindingRule = null, resultType:ResultType = null, polySize:Int = 3, vertexDim:Int = 2, normal:Array<Float> = null):TessResult
  {
    var tess = new Tesselator();
    for (i in 0...contours.length) {
      tess.addContour(vertexDim, contours[i]);
    }
    tess.tesselate(windingRule == null ? WindingRule.ODD : windingRule,
             resultType == null ? ResultType.POLYGONS : resultType,
             polySize,
             vertexDim,
             normal == null ? [0, 0, 1] : normal);
    return {
      vertices: tess.vertices,
      vertexIndices: tess.vertexIndices,
      vertexCount: tess.vertexCount,
      elements: tess.elements,
      elementCount: tess.elementCount,
    };
  }
  
  /** 
   * Computes the union between `contoursA` and `contoursB`. 
   *
   * @see "CSG Uses for Winding Rules" section on http://www.glprogramming.com/red/chapter11.html
   */
  static public function union(contoursA:Array<Array<Float>>, contoursB:Array<Array<Float>>, resultType:ResultType = null, polySize:Int = 3, vertexDim:Int = 2):TessResult
  {
    var contours = contoursA.concat(contoursB);
    return tesselate(contours, WindingRule.NON_ZERO, resultType, polySize, vertexDim);
  }
  
  /** 
   * Computes the intersection between `contoursA` and `contoursB`.
   *
   * @see "CSG Uses for Winding Rules" section on http://www.glprogramming.com/red/chapter11.html
   */
  static public function intersection(contoursA:Array<Array<Float>>, contoursB:Array<Array<Float>>, resultType:ResultType = null, polySize:Int = 3, vertexDim:Int = 2):TessResult
  {
    var contours = contoursA.concat(contoursB);
    return tesselate(contours, WindingRule.ABS_GEQ_TWO, resultType, polySize, vertexDim);
  }
  
  /** 
   * Computes `contoursA` - `contoursB`.
   *
   * @see "CSG Uses for Winding Rules" section on http://www.glprogramming.com/red/chapter11.html
   */
  static public function difference(contoursA:Array<Array<Float>>, contoursB:Array<Array<Float>>, resultType:ResultType = null, polySize:Int = 3, vertexDim:Int = 2):TessResult
  {
    var diffB = [for (poly in contoursB) PolyTools.reverseFloatArray(poly)];
    var contours = contoursA.concat(diffB);
    return tesselate(contours, WindingRule.POSITIVE, resultType, polySize, vertexDim);
  }
  
  /**
   * Converts the results from tesselate() in a more manageable output.
   * 
   * @param	vertices	A sequence of point coords in the same format of `contours`. Typically the `vertices` field of Tess2.tesselate() output.
   * @param	elements	A sequence of elements. Typically the `vertices` field of Tess2.tesselate() output.
   * @param	resultType	The `resultType` passed to Tess2.tesselate().
   * @param	polySize	The `polySize` passed to Tess2.tesselate().
   * @param	out			The output will be appended to this array of polygons (if specified).
   * 
   * @return An array of polygons.
   */
  static public function convertResult(vertices:Array<Float>, elements:Array<Int>, resultType:ResultType, polySize:Int, ?out:Array<Poly>):Array<Poly>
  {
    out = (out != null) ? out : new Array<Poly>();
    
    if (!resultType.match(BOUNDARY_CONTOURS)) {
      Debug.assert(polySize >= 3 && (elements.length % polySize == 0), "Invalid size");
    }
    
    var i = 0;
    switch (resultType) 
    {
      case ResultType.POLYGONS, ResultType.EXPERIMENTAL_DELAUNAY:
        while (i < elements.length) {
          var poly = [];
          for (j in 0...polySize) {
            var idx = elements[i + j];
            if (idx == -1) continue;
            poly.push(new HxPoint(vertices[idx * 2 + 0], vertices[idx * 2 + 1]));
          }
          out.push(poly);
          i += polySize;
        }
        
      case ResultType.CONNECTED_POLYGONS:
        while (i < elements.length) {
          var poly = [];
          for (j in 0...polySize) {
            var idx = elements[i + j];
            if (idx == -1) continue;
            poly.push(new HxPoint(vertices[idx * 2 + 0], vertices[idx * 2 + 1]));
          }
          out.push(poly);
          i += polySize * 2;
        }
        
      case ResultType.BOUNDARY_CONTOURS:
        while (i < elements.length) {
          var poly = [];
          var start = elements[i + 0];
          var count = elements[i + 1];
          for (j in 0...count) {
            var idx = start + j;
            poly.push(new HxPoint(vertices[idx * 2 + 0], vertices[idx * 2 + 1]));
          }
          out.push(poly);
          i += 2;
        }
    }
    
    return out;
  }	
}

/* The mesh structure is similar in spirit, notation, and operations
* to the "quad-edge" structure (see L. Guibas and J. Stolfi, Primitives
* for the manipulation of general subdivisions and the computation of
* Voronoi diagrams, ACM Transactions on Graphics, 4(2):74-123, April 1985).
* For a simplified description, see the course notes for CS348a,
* "Mathematical Foundations of Computer Graphics", available at the
* Stanford bookstore (and taught during the fall quarter).
* The implementation also borrows a tiny subset of the graph-based approach
* use in Mantyla's Geometric Work Bench (see M. Mantyla, An Introduction
* to Sold Modeling, Computer Science Press, Rockville, Maryland, 1988).
*
* The fundamental data structure is the "half-edge".  Two half-edges
* go together to make an edge, but they point in opposite directions.
* Each half-edge has a pointer to its mate (the "symmetric" half-edge Sym),
* its origin vertex (Org), the face on its left side (Lface), and the
* adjacent half-edges in the CCW direction around the origin vertex
* (Onext) and around the left face (Lnext).  There is also a "next"
* pointer for the global edge list (see below).
*
* The notation used for mesh navigation:
*  Sym   = the mate of a half-edge (same edge, but opposite direction)
*  Onext = edge CCW around origin vertex (keep same origin)
*  Dnext = edge CCW around destination vertex (keep same dest)
*  Lnext = edge CCW around left face (dest becomes new origin)
*  Rnext = edge CCW around right face (origin becomes new dest)
*
* "prev" means to substitute CW for CCW in the definitions above.
*
* The mesh keeps global lists of all vertices, faces, and edges,
* stored as doubly-linked circular lists with a dummy header node.
* The mesh stores pointers to these dummy headers (vHead, fHead, eHead).
*
* The circular edge list is special; since half-edges always occur
* in pairs (e and e->Sym), each half-edge stores a pointer in only
* one direction.  Starting at eHead and following the e->next pointers
* will visit each *edge* once (ie. e or e->Sym, but not both).
* e->Sym stores a pointer in the opposite direction, thus it is
* always true that e->Sym->next->Sym->next == e.
*
* Each vertex has a pointer to next and previous vertices in the
* circular list, and a pointer to a half-edge with this vertex as
* the origin (NULL if this is the dummy header).  There is also a
* field "data" for client data.
*
* Each face has a pointer to the next and previous faces in the
* circular list, and a pointer to a half-edge with this face as
* the left face (NULL if this is the dummy header).  There is also
* a field "data" for client data.
*
* Note that what we call a "face" is really a loop; faces may consist
* of more than one loop (ie. not simply connected), but there is no
* record of this in the data structure.  The mesh may consist of
* several disconnected regions, so it may not be possible to visit
* the entire mesh by starting at a half-edge and traversing the edge
* structure.
*
* The mesh does NOT support isolated vertices; a vertex is deleted along
* with its last edge.  Similarly when two faces are merged, one of the
* faces is deleted (see tessMeshDelete below).  For mesh operations,
* all face (loop) and vertex pointers must not be NULL.  However, once
* mesh manipulation is finished, TESSmeshZapFace can be used to delete
* faces of the mesh, one at a time.  All external faces can be "zapped"
* before the mesh is returned to the client; then a NULL face indicates
* a region which is not part of the output polygon.
*/

private class TessVertex 
{
  
  public var next:TessVertex = null;			/* next vertex (never NULL) */
  public var prev:TessVertex = null;			/* previous vertex (never NULL) */
  public var anEdge:TessHalfEdge = null;		/* a half-edge with this origin */

  /* Internal data (keep hidden) */
  public var coords:Array<Float> = [0,0,0];	/* vertex location in 3D */
  public var s:Float = 0.0;
  public var t:Float = 0.0;					/* projection onto the sweep plane */
  public var pqHandle:Int = 0;				/* to allow deletion from priority queue */
  public var n:Int = 0;						/* to allow identify unique vertices */
  public var idx:Int = 0;						/* to allow map result to original verts */
  
  public function new() {}
} 

private class TessFace 
{
  public var next:TessFace = null;			/* next face (never NULL) */
  public var prev:TessFace = null;			/* previous face (never NULL) */
  public var anEdge:TessHalfEdge = null;		/* a half-edge with this left face */

  /* Internal data (keep hidden) */
  public var trail:TessFace = null;			/* "stack" for conversion to strips */
  public var n:Int = 0;						/* to allow identiy unique faces */
  public var marked:Bool = false;				/* flag for conversion to strips */
  public var inside:Bool = false;				/* this face is in the polygon interior */
  
  public function new() {}
} 

private class TessHalfEdge
{
  public var next:TessHalfEdge = null;		/* doubly-linked list (prev==Sym->next) */
  public var Sym:TessHalfEdge = null;			/* same edge, opposite direction */
  public var Onext:TessHalfEdge = null;		/* next edge CCW around origin */
  public var Lnext:TessHalfEdge = null;		/* next edge CCW around left face */
  public var Org:TessVertex = null;			/* origin vertex (Overtex too long) */
  public var Lface:TessFace = null;			/* left face */

  /* Internal data (keep hidden) */
  public var activeRegion:ActiveRegion = null;/* a region with this upper edge (sweep.c) */
  public var winding = 0;						/* change in winding number when crossing
                           from the right face to the left face */
  public var side:Int;						/* 0 for original dir, 1 for symmetric */
  public var mark:Bool; 						/* Used by the Edge Flip algorithm */
  
  public function new(side:Int)
  {
    this.side = side;
  }
  
  public var Rface(get, set):TessFace;
  private function get_Rface():TessFace { return this.Sym.Lface; }
  private function set_Rface(v:TessFace) { return this.Sym.Lface = v; }
  
  public var Dst(get, set):TessVertex;
  private function get_Dst():TessVertex { return this.Sym.Org; }
  private function set_Dst(v:TessVertex) { return this.Sym.Org = v; }
  
  public var Oprev(get, set):TessHalfEdge;
  private function get_Oprev():TessHalfEdge { return this.Sym.Lnext; }
  private function set_Oprev(v:TessHalfEdge) { return this.Sym.Lnext = v; }
  
  public var Lprev(get, set):TessHalfEdge;
  private function get_Lprev():TessHalfEdge { return this.Onext.Sym; }
  private function set_Lprev(v:TessHalfEdge) { return this.Onext.Sym = v; }
  
  public var Dprev(get, set):TessHalfEdge;
  private function get_Dprev():TessHalfEdge { return this.Lnext.Sym; }
  private function set_Dprev(v:TessHalfEdge) { return this.Lnext.Sym = v; }
  
  public var Rprev(get, set):TessHalfEdge;
  private function get_Rprev():TessHalfEdge { return this.Sym.Onext; }
  private function set_Rprev(v:TessHalfEdge) { return this.Sym.Onext = v; }
  
  public var Dnext(get, set):TessHalfEdge;
  private function get_Dnext() { return /*this.Rprev*/this.Sym.Onext.Sym; }  /* 3 pointers */
  private function set_Dnext(v:TessHalfEdge) { return/*this.Rprev*/this.Sym.Onext.Sym = v; }  /* 3 pointers */
  
  public var Rnext(get, set):TessHalfEdge;
  private function get_Rnext():TessHalfEdge { return /*this.Oprev*/this.Sym.Lnext.Sym; }  /* 3 pointers */
  private function set_Rnext(v:TessHalfEdge) { return/*this.Oprev*/this.Sym.Lnext.Sym = v; }  /* 3 pointers */
}

private class TessMesh
{
  public var v:TessVertex = new TessVertex();
  public var f:TessFace = new TessFace();
  public var e:TessHalfEdge = new TessHalfEdge(0);
  public var eSym:TessHalfEdge = new TessHalfEdge(1);

  public var vHead:TessVertex;			/* dummy header for vertex list */
  public var fHead:TessFace;				/* dummy header for face list */
  public var eHead:TessHalfEdge;			/* dummy header for edge list */
  public var eHeadSym:TessHalfEdge;		/* and its symmetric counterpart */
  
  public function new() 
  {
    v.next = v.prev = v;
    v.anEdge = null;

    f.next = f.prev = f;
    f.anEdge = null;
    f.trail = null;
    f.marked = false;
    f.inside = false;

    e.next = e;
    e.Sym = eSym;
    e.Onext = null;
    e.Lnext = null;
    e.Org = null;
    e.Lface = null;
    e.winding = 0;
    e.activeRegion = null;
    e.mark = false;
    
    eSym.next = eSym;
    eSym.Sym = e;
    eSym.Onext = null;
    eSym.Lnext = null;
    eSym.Org = null;
    eSym.Lface = null;
    eSym.winding = 0;
    eSym.activeRegion = null;
    e.Sym.mark = false;
    
    this.vHead = v;			/* dummy header for vertex list */
    this.fHead = f;			/* dummy header for face list */
    this.eHead = e;			/* dummy header for edge list */
    this.eHeadSym = eSym;	/* and its symmetric counterpart */
  }
  
  /* The mesh operations below have three motivations: completeness,
  * convenience, and efficiency.  The basic mesh operations are MakeEdge,
  * Splice, and Delete.  All the other edge operations can be implemented
  * in terms of these.  The other operations are provided for convenience
  * and/or efficiency.
  *
  * When a face is split or a vertex is added, they are inserted into the
  * global list *before* the existing vertex or face (ie. e->Org or e->Lface).
  * This makes it easier to process all vertices or faces in the global lists
  * without worrying about processing the same data twice.  As a convenience,
  * when a face is split, the "inside" flag is copied from the old face.
  * Other internal data (v->data, v->activeRegion, f->data, f->marked,
  * f->trail, e->winding) is set to zero.
  *
  * ********************** Basic Edge Operations **************************
  *
  * tessMeshMakeEdge( mesh ) creates one edge, two vertices, and a loop.
  * The loop (face) consists of the two new half-edges.
  *
  * tessMeshSplice( eOrg, eDst ) is the basic operation for changing the
  * mesh connectivity and topology.  It changes the mesh so that
  *  eOrg->Onext <- OLD( eDst->Onext )
  *  eDst->Onext <- OLD( eOrg->Onext )
  * where OLD(...) means the value before the meshSplice operation.
  *
  * This can have two effects on the vertex structure:
  *  - if eOrg->Org != eDst->Org, the two vertices are merged together
  *  - if eOrg->Org == eDst->Org, the origin is split into two vertices
  * In both cases, eDst->Org is changed and eOrg->Org is untouched.
  *
  * Similarly (and independently) for the face structure,
  *  - if eOrg->Lface == eDst->Lface, one loop is split into two
  *  - if eOrg->Lface != eDst->Lface, two distinct loops are joined into one
  * In both cases, eDst->Lface is changed and eOrg->Lface is unaffected.
  *
  * tessMeshDelete( eDel ) removes the edge eDel.  There are several cases:
  * if (eDel->Lface != eDel->Rface), we join two loops into one; the loop
  * eDel->Lface is deleted.  Otherwise, we are splitting one loop into two;
  * the newly created loop will contain eDel->Dst.  If the deletion of eDel
  * would create isolated vertices, those are deleted as well.
  *
  * ********************** Other Edge Operations **************************
  *
  * tessMeshAddEdgeVertex( eOrg ) creates a new edge eNew such that
  * eNew == eOrg->Lnext, and eNew->Dst is a newly created vertex.
  * eOrg and eNew will have the same left face.
  *
  * tessMeshSplitEdge( eOrg ) splits eOrg into two edges eOrg and eNew,
  * such that eNew == eOrg->Lnext.  The new vertex is eOrg->Dst == eNew->Org.
  * eOrg and eNew will have the same left face.
  *
  * tessMeshConnect( eOrg, eDst ) creates a new edge from eOrg->Dst
  * to eDst->Org, and returns the corresponding half-edge eNew.
  * If eOrg->Lface == eDst->Lface, this splits one loop into two,
  * and the newly created loop is eNew->Lface.  Otherwise, two disjoint
  * loops are merged into one, and the loop eDst->Lface is destroyed.
  *
  * ************************ Other Operations *****************************
  *
  * tessMeshNewMesh() creates a new mesh with no edges, no vertices,
  * and no loops (what we usually call a "face").
  *
  * tessMeshUnion( mesh1, mesh2 ) forms the union of all structures in
  * both meshes, and returns the new mesh (the old meshes are destroyed).
  *
  * tessMeshDeleteMesh( mesh ) will free all storage for any valid mesh.
  *
  * tessMeshZapFace( fZap ) destroys a face and removes it from the
  * global face list.  All edges of fZap will have a NULL pointer as their
  * left face.  Any edges which also have a NULL pointer as their right face
  * are deleted entirely (along with any isolated vertices this produces).
  * An entire mesh can be deleted by zapping its faces, one at a time,
  * in any order.  Zapped faces cannot be used in further mesh operations!
  *
  * tessMeshCheckMesh( mesh ) checks a mesh for self-consistency.
  */
  
  /* MakeEdge creates a new pair of half-edges which form their own loop.
  * No vertex or face structures are allocated, but these must be assigned
  * before the current edge operation is completed.
  */
  //static TESShalfEdge *MakeEdge( TESSmesh* mesh, TESShalfEdge *eNext )
  private function makeEdge_(eNext:TessHalfEdge):TessHalfEdge {
    var e = new TessHalfEdge(0);
    var eSym = new TessHalfEdge(1);

    /* Make sure eNext points to the first edge of the edge pair */
    if (eNext.Sym.side < eNext.side) { eNext = eNext.Sym; }

    /* Insert in circular doubly-linked list before eNext.
    * Note that the prev pointer is stored in Sym->next.
    */
    var ePrev = eNext.Sym.next;
    eSym.next = ePrev;
    ePrev.Sym.next = e;
    e.next = eNext;
    eNext.Sym.next = eSym;

    e.Sym = eSym;
    e.Onext = e;
    e.Lnext = eSym;
    e.Org = null;
    e.Lface = null;
    e.winding = 0;
    e.activeRegion = null;

    eSym.Sym = e;
    eSym.Onext = eSym;
    eSym.Lnext = e;
    eSym.Org = null;
    eSym.Lface = null;
    eSym.winding = 0;
    eSym.activeRegion = null;

    return e;
  }

  /* Splice( a, b ) is best described by the Guibas/Stolfi paper or the
  * CS348a notes (see mesh.h).  Basically it modifies the mesh so that
  * a->Onext and b->Onext are exchanged.  This can have various effects
  * depending on whether a and b belong to different face or vertex rings.
  * For more explanation see tessMeshSplice() below.
  */
  // static void Splice( TESShalfEdge *a, TESShalfEdge *b )
  private function splice_(a:TessHalfEdge, b:TessHalfEdge) {
    var aOnext = a.Onext;
    var bOnext = b.Onext;
    aOnext.Sym.Lnext = b;
    bOnext.Sym.Lnext = a;
    a.Onext = bOnext;
    b.Onext = aOnext;
  }

  /* MakeVertex( newVertex, eOrig, vNext ) attaches a new vertex and makes it the
  * origin of all edges in the vertex loop to which eOrig belongs. "vNext" gives
  * a place to insert the new vertex in the global vertex list.  We insert
  * the new vertex *before* vNext so that algorithms which walk the vertex
  * list will not see the newly created vertices.
  */
  //static void MakeVertex( TESSvertex *newVertex, TESShalfEdge *eOrig, TESSvertex *vNext )
  private function makeVertex_(newVertex:TessVertex, eOrig:TessHalfEdge, vNext:TessVertex) {
    var vNew = newVertex;
    Debug.assert(vNew != null);

    /* insert in circular doubly-linked list before vNext */
    var vPrev = vNext.prev;
    vNew.prev = vPrev;
    vPrev.next = vNew;
    vNew.next = vNext;
    vNext.prev = vNew;

    vNew.anEdge = eOrig;
    /* leave coords, s, t undefined */

    /* fix other edges on this vertex loop */
    var e = eOrig;
    do {
      e.Org = vNew;
      e = e.Onext;
    } while (e != eOrig);
  }

  /* MakeFace( newFace, eOrig, fNext ) attaches a new face and makes it the left
  * face of all edges in the face loop to which eOrig belongs.  "fNext" gives
  * a place to insert the new face in the global face list.  We insert
  * the new face *before* fNext so that algorithms which walk the face
  * list will not see the newly created faces.
  */
  // static void MakeFace( TESSface *newFace, TESShalfEdge *eOrig, TESSface *fNext )
  private function makeFace_(newFace:TessFace, eOrig:TessHalfEdge, fNext:TessFace) {
    var fNew = newFace;
    Debug.assert(fNew != null); 

    /* insert in circular doubly-linked list before fNext */
    var fPrev = fNext.prev;
    fNew.prev = fPrev;
    fPrev.next = fNew;
    fNew.next = fNext;
    fNext.prev = fNew;

    fNew.anEdge = eOrig;
    fNew.trail = null;
    fNew.marked = false;

    /* The new face is marked "inside" if the old one was.  This is a
    * convenience for the common case where a face has been split in two.
    */
    fNew.inside = fNext.inside;

    /* fix other edges on this face loop */
    var e = eOrig;
    do {
      e.Lface = fNew;
      e = e.Lnext;
    } while (e != eOrig);
  }

  /* KillEdge( eDel ) destroys an edge (the half-edges eDel and eDel->Sym),
  * and removes from the global edge list.
  */
  //static void KillEdge( TESSmesh *mesh, TESShalfEdge *eDel )
  private function killEdge_(eDel:TessHalfEdge) {
    /* Half-edges are allocated in pairs, see EdgePair above */
    if (eDel.Sym.side < eDel.side) { eDel = eDel.Sym; }

    /* delete from circular doubly-linked list */
    var eNext = eDel.next;
    var ePrev = eDel.Sym.next;
    eNext.Sym.next = ePrev;
    ePrev.Sym.next = eNext;
  }

  /* KillVertex( vDel ) destroys a vertex and removes it from the global
  * vertex list.  It updates the vertex loop to point to a given new vertex.
  */
  //static void KillVertex( TESSmesh *mesh, TESSvertex *vDel, TESSvertex *newOrg )
  private function killVertex_(vDel:TessVertex, newOrg:TessVertex) {
    var eStart = vDel.anEdge;
    /* change the origin of all affected edges */
    var e = eStart;
    do {
      e.Org = newOrg;
      e = e.Onext;
    } while (e != eStart);

    /* delete from circular doubly-linked list */
    var vPrev = vDel.prev;
    var vNext = vDel.next;
    vNext.prev = vPrev;
    vPrev.next = vNext;
  }

  /* KillFace( fDel ) destroys a face and removes it from the global face
  * list.  It updates the face loop to point to a given new face.
  */
  //static void KillFace( TESSmesh *mesh, TESSface *fDel, TESSface *newLface )
  private function killFace_(fDel:TessFace, newLface:TessFace) {
    var eStart = fDel.anEdge;

    /* change the left face of all affected edges */
    var e = eStart;
    do {
      e.Lface = newLface;
      e = e.Lnext;
    } while (e != eStart);

    /* delete from circular doubly-linked list */
    var fPrev = fDel.prev;
    var fNext = fDel.next;
    fNext.prev = fPrev;
    fPrev.next = fNext;
  }
  
  /****************** Basic Edge Operations **********************/

  /* tessMeshMakeEdge creates one edge, two vertices, and a loop (face).
  * The loop consists of the two new half-edges.
  */
  //TESShalfEdge *tessMeshMakeEdge( TESSmesh *mesh )
  public function makeEdge():TessHalfEdge {
    var newVertex1 = new TessVertex();
    var newVertex2 = new TessVertex();
    var newFace = new TessFace();
    var e = this.makeEdge_(this.eHead);
    this.makeVertex_(newVertex1, e, this.vHead);
    this.makeVertex_(newVertex2, e.Sym, this.vHead);
    this.makeFace_(newFace, e, this.fHead);
    return e;
  }

  /* tessMeshSplice( eOrg, eDst ) is the basic operation for changing the
  * mesh connectivity and topology.  It changes the mesh so that
  *	eOrg->Onext <- OLD( eDst->Onext )
  *	eDst->Onext <- OLD( eOrg->Onext )
  * where OLD(...) means the value before the meshSplice operation.
  *
  * This can have two effects on the vertex structure:
  *  - if eOrg->Org != eDst->Org, the two vertices are merged together
  *  - if eOrg->Org == eDst->Org, the origin is split into two vertices
  * In both cases, eDst->Org is changed and eOrg->Org is untouched.
  *
  * Similarly (and independently) for the face structure,
  *  - if eOrg->Lface == eDst->Lface, one loop is split into two
  *  - if eOrg->Lface != eDst->Lface, two distinct loops are joined into one
  * In both cases, eDst->Lface is changed and eOrg->Lface is unaffected.
  *
  * Some special cases:
  * If eDst == eOrg, the operation has no effect.
  * If eDst == eOrg->Lnext, the new face will have a single edge.
  * If eDst == eOrg->Lprev, the old face will have a single edge.
  * If eDst == eOrg->Onext, the new vertex will have a single edge.
  * If eDst == eOrg->Oprev, the old vertex will have a single edge.
  */
  //int tessMeshSplice( TESSmesh* mesh, TESShalfEdge *eOrg, TESShalfEdge *eDst )
  public function splice(eOrg:TessHalfEdge, eDst:TessHalfEdge) {
    var joiningLoops = false;
    var joiningVertices = false;

    if (eOrg == eDst) return;

    if (eDst.Org != eOrg.Org) {
      /* We are merging two disjoint vertices -- destroy eDst->Org */
      joiningVertices = true;
      this.killVertex_(eDst.Org, eOrg.Org);
    }
    if (eDst.Lface != eOrg.Lface) {
      /* We are connecting two disjoint loops -- destroy eDst->Lface */
      joiningLoops = true;
      this.killFace_(eDst.Lface, eOrg.Lface);
    }

    /* Change the edge structure */
    this.splice_(eDst, eOrg);

    if (!joiningVertices) {
      var newVertex = new TessVertex();

      /* We split one vertex into two -- the new vertex is eDst->Org.
      * Make sure the old vertex points to a valid half-edge.
      */
      this.makeVertex_(newVertex, eDst, eOrg.Org);
      eOrg.Org.anEdge = eOrg;
    }
    if (!joiningLoops) {
      var newFace = new TessFace();  

      /* We split one loop into two -- the new loop is eDst->Lface.
      * Make sure the old face points to a valid half-edge.
      */
      this.makeFace_(newFace, eDst, eOrg.Lface);
      eOrg.Lface.anEdge = eOrg;
    }
  }

  //void tessMeshFlipEdge( TESSmesh *mesh, TESShalfEdge *edge )
  static public function flipEdge(mesh:TessMesh, edge:TessHalfEdge):Void
  {
    var a0:TessHalfEdge = edge;
    var a1:TessHalfEdge = a0.Lnext;
    var a2:TessHalfEdge = a1.Lnext;
    var b0:TessHalfEdge = edge.Sym;
    var b1:TessHalfEdge = b0.Lnext;
    var b2:TessHalfEdge = b1.Lnext;

    var aOrg:TessVertex = a0.Org;
    var aOpp:TessVertex = a2.Org;
    var bOrg:TessVertex = b0.Org;
    var bOpp:TessVertex = b2.Org;

    var fa:TessFace = a0.Lface;
    var fb:TessFace = b0.Lface;

    Debug.assert(Geom.edgeIsInternal(edge));
    Debug.assert(a2.Lnext == a0);
    Debug.assert(b2.Lnext == b0);

    a0.Org = bOpp;
    a0.Onext = b1.Sym;
    b0.Org = aOpp;
    b0.Onext = a1.Sym;
    a2.Onext = b0;
    b2.Onext = a0;
    b1.Onext = a2.Sym;
    a1.Onext = b2.Sym;

    a0.Lnext = a2;
    a2.Lnext = b1;
    b1.Lnext = a0;

    b0.Lnext = b2;
    b2.Lnext = a1;
    a1.Lnext = b0;

    a1.Lface = fb;
    b1.Lface = fa;

    fa.anEdge = a0;
    fb.anEdge = b0;

    if (aOrg.anEdge == a0) aOrg.anEdge = b1;
    if (bOrg.anEdge == b0) bOrg.anEdge = a1;

    Debug.assert(a0.Lnext.Onext.Sym == a0);
    Debug.assert(a0.Onext.Sym.Lnext == a0);
    Debug.assert(a0.Org.anEdge.Org == a0.Org);


    Debug.assert(a1.Lnext.Onext.Sym == a1);
    Debug.assert(a1.Onext.Sym.Lnext == a1);
    Debug.assert(a1.Org.anEdge.Org == a1.Org);

    Debug.assert(a2.Lnext.Onext.Sym == a2);
    Debug.assert(a2.Onext.Sym.Lnext == a2);
    Debug.assert(a2.Org.anEdge.Org == a2.Org);

    Debug.assert(b0.Lnext.Onext.Sym == b0);
    Debug.assert(b0.Onext.Sym.Lnext == b0);
    Debug.assert(b0.Org.anEdge.Org == b0.Org);

    Debug.assert(b1.Lnext.Onext.Sym == b1);
    Debug.assert(b1.Onext.Sym.Lnext == b1);
    Debug.assert(b1.Org.anEdge.Org == b1.Org);

    Debug.assert(b2.Lnext.Onext.Sym == b2);
    Debug.assert(b2.Onext.Sym.Lnext == b2);
    Debug.assert(b2.Org.anEdge.Org == b2.Org);

    Debug.assert(aOrg.anEdge.Org == aOrg);
    Debug.assert(bOrg.anEdge.Org == bOrg);

    Debug.assert(a0.Oprev.Onext.Org == a0.Org);
  }

  /* tessMeshDelete( eDel ) removes the edge eDel.  There are several cases:
  * if (eDel->Lface != eDel->Rface), we join two loops into one; the loop
  * eDel->Lface is deleted.  Otherwise, we are splitting one loop into two;
  * the newly created loop will contain eDel->Dst.  If the deletion of eDel
  * would create isolated vertices, those are deleted as well.
  *
  * This function could be implemented as two calls to tessMeshSplice
  * plus a few calls to memFree, but this would allocate and delete
  * unnecessary vertices and faces.
  */
  //int tessMeshDelete( TESSmesh *mesh, TESShalfEdge *eDel )
  public function delete(eDel:TessHalfEdge) {
    var eDelSym = eDel.Sym;
    var joiningLoops = false;

    /* First step: disconnect the origin vertex eDel->Org.  We make all
    * changes to get a consistent mesh in this "intermediate" state.
    */
    if (eDel.Lface != eDel.Rface) {
      /* We are joining two loops into one -- remove the left face */
      joiningLoops = true;
      this.killFace_(eDel.Lface, eDel.Rface);
    }

    if (eDel.Onext == eDel ) {
      this.killVertex_(eDel.Org, null);
    } else {
      /* Make sure that eDel->Org and eDel->Rface point to valid half-edges */
      eDel.Rface.anEdge = eDel.Oprev;
      eDel.Org.anEdge = eDel.Onext;

      this.splice_(eDel, eDel.Oprev);
      if (!joiningLoops) {
        var newFace = new TessFace();

        /* We are splitting one loop into two -- create a new loop for eDel. */
        this.makeFace_(newFace, eDel, eDel.Lface);
      }
    }

    /* Claim: the mesh is now in a consistent state, except that eDel->Org
    * may have been deleted.  Now we disconnect eDel->Dst.
    */
    if (eDelSym.Onext == eDelSym) {
      this.killVertex_(eDelSym.Org, null);
      this.killFace_(eDelSym.Lface, null);
    } else {
      /* Make sure that eDel->Dst and eDel->Lface point to valid half-edges */
      eDel.Lface.anEdge = eDelSym.Oprev;
      eDelSym.Org.anEdge = eDelSym.Onext;
      this.splice_(eDelSym, eDelSym.Oprev);
    }

    /* Any isolated vertices or faces have already been freed. */
    this.killEdge_(eDel);
  }

  /******************** Other Edge Operations **********************/

  /* All these routines can be implemented with the basic edge
  * operations above.  They are provided for convenience and efficiency.
  */


  /* tessMeshAddEdgeVertex( eOrg ) creates a new edge eNew such that
  * eNew == eOrg->Lnext, and eNew->Dst is a newly created vertex.
  * eOrg and eNew will have the same left face.
  */
  // TESShalfEdge *tessMeshAddEdgeVertex( TESSmesh *mesh, TESShalfEdge *eOrg );
  public function addEdgeVertex(eOrg:TessHalfEdge):TessHalfEdge {
    var eNew = this.makeEdge_(eOrg);
    var eNewSym = eNew.Sym;

    /* Connect the new edge appropriately */
    this.splice_(eNew, eOrg.Lnext);

    /* Set the vertex and face information */
    eNew.Org = eOrg.Dst;

    var newVertex = new TessVertex();
    this.makeVertex_(newVertex, eNewSym, eNew.Org);

    eNew.Lface = eNewSym.Lface = eOrg.Lface;

    return eNew;
  }


  /* tessMeshSplitEdge( eOrg ) splits eOrg into two edges eOrg and eNew,
  * such that eNew == eOrg->Lnext.  The new vertex is eOrg->Dst == eNew->Org.
  * eOrg and eNew will have the same left face.
  */
  // TESShalfEdge *tessMeshSplitEdge( TESSmesh *mesh, TESShalfEdge *eOrg );
  public function splitEdge(eOrg:TessHalfEdge):TessHalfEdge {
    var tempHalfEdge = this.addEdgeVertex(eOrg);
    var eNew = tempHalfEdge.Sym;

    /* Disconnect eOrg from eOrg->Dst and connect it to eNew->Org */
    this.splice_(eOrg.Sym, eOrg.Sym.Oprev);
    this.splice_(eOrg.Sym, eNew);

    /* Set the vertex and face information */
    eOrg.Dst = eNew.Org;
    eNew.Dst.anEdge = eNew.Sym;	/* may have pointed to eOrg->Sym */
    eNew.Rface = eOrg.Rface;
    eNew.winding = eOrg.winding;	/* copy old winding information */
    eNew.Sym.winding = eOrg.Sym.winding;

    return eNew;
  }
  
  /* tessMeshConnect( eOrg, eDst ) creates a new edge from eOrg->Dst
  * to eDst->Org, and returns the corresponding half-edge eNew.
  * If eOrg->Lface == eDst->Lface, this splits one loop into two,
  * and the newly created loop is eNew->Lface.  Otherwise, two disjoint
  * loops are merged into one, and the loop eDst->Lface is destroyed.
  *
  * If (eOrg == eDst), the new face will have only two edges.
  * If (eOrg->Lnext == eDst), the old face is reduced to a single edge.
  * If (eOrg->Lnext->Lnext == eDst), the old face is reduced to two edges.
  */
  // TESShalfEdge *tessMeshConnect( TESSmesh *mesh, TESShalfEdge *eOrg, TESShalfEdge *eDst );
  public function connect(eOrg:TessHalfEdge, eDst:TessHalfEdge):TessHalfEdge {
    var joiningLoops = false;  
    var eNew = this.makeEdge_(eOrg);
    var eNewSym = eNew.Sym;

    if (eDst.Lface != eOrg.Lface) {
      /* We are connecting two disjoint loops -- destroy eDst->Lface */
      joiningLoops = true;
      this.killFace_(eDst.Lface, eOrg.Lface);
    }

    /* Connect the new edge appropriately */
    this.splice_(eNew, eOrg.Lnext);
    this.splice_(eNewSym, eDst);

    /* Set the vertex and face information */
    eNew.Org = eOrg.Dst;
    eNewSym.Org = eDst.Org;
    eNew.Lface = eNewSym.Lface = eOrg.Lface;

    /* Make sure the old face points to a valid half-edge */
    eOrg.Lface.anEdge = eNewSym;

    if (!joiningLoops) {
      var newFace = new TessFace();
      /* We split one loop into two -- the new loop is eNew->Lface */
      this.makeFace_(newFace, eNew, eOrg.Lface);
    }
    return eNew;
  }

  /* tessMeshZapFace( fZap ) destroys a face and removes it from the
  * global face list.  All edges of fZap will have a NULL pointer as their
  * left face.  Any edges which also have a NULL pointer as their right face
  * are deleted entirely (along with any isolated vertices this produces).
  * An entire mesh can be deleted by zapping its faces, one at a time,
  * in any order.  Zapped faces cannot be used in further mesh operations!
  */
  public function zapFace(fZap:TessFace):Void
  {
    var eStart = fZap.anEdge;
    var e, eNext, eSym;
    var fPrev, fNext;

    /* walk around face, deleting edges whose right face is also NULL */
    eNext = eStart.Lnext;
    do {
      e = eNext;
      eNext = e.Lnext;

      e.Lface = null;
      if (e.Rface == null) {
        /* delete the edge -- see TESSmeshDelete above */

        if (e.Onext == e) {
          this.killVertex_(e.Org, null);
        } else {
          /* Make sure that e->Org points to a valid half-edge */
          e.Org.anEdge = e.Onext;
          this.splice_(e, e.Oprev);
        }
        eSym = e.Sym;
        if (eSym.Onext == eSym) {
          this.killVertex_(eSym.Org, null);
        } else {
          /* Make sure that eSym->Org points to a valid half-edge */
          eSym.Org.anEdge = eSym.Onext;
          this.splice_(eSym, eSym.Oprev);
        }
        this.killEdge_(e);
      }
    } while (e != eStart);

    /* delete from circular doubly-linked list */
    fPrev = fZap.prev;
    fNext = fZap.next;
    fNext.prev = fPrev;
    fPrev.next = fNext;
  }
  
  private function countFaceVerts_(f:TessFace):Int {
    var eCur = f.anEdge;
    var n = 0;
    do
    {
      n++;
      eCur = eCur.Lnext;
    }
    while (eCur != f.anEdge);
    return n;
  }

  //int tessMeshMergeConvexFaces( TESSmesh *mesh, int maxVertsPerFace )
  public function mergeConvexFaces(maxVertsPerFace:Int):Bool {
    var f:TessFace;
    var eCur, eNext, eSym;
    var vStart;
    var curNv, symNv;

    f = this.fHead.next;
    while (f != this.fHead)
    {
      // Skip faces which are outside the result.
      if (!f.inside) {
        f = f.next;
        continue;
      }

      eCur = f.anEdge;
      vStart = eCur.Org;
        
      while (true)
      {
        eNext = eCur.Lnext;
        eSym = eCur.Sym;

        // Try to merge if the neighbour face is valid.
        if (eSym != null && eSym.Lface != null && eSym.Lface.inside)
        {
          // Try to merge the neighbour faces if the resulting polygons
          // does not exceed maximum number of vertices.
          curNv = this.countFaceVerts_(f);
          symNv = this.countFaceVerts_(eSym.Lface);
          if ((curNv + symNv - 2) <= maxVertsPerFace)
          {
            // Merge if the resulting poly is convex.
            if (Geom.vertCCW(eCur.Lprev.Org, eCur.Org, eSym.Lnext.Lnext.Org) &&
              Geom.vertCCW(eSym.Lprev.Org, eSym.Org, eCur.Lnext.Lnext.Org))
            {
              eNext = eSym.Lnext;
              this.delete(eSym);
              eCur = null;
              eSym = null;
            }
          }
        }
        
        if (eCur != null && eCur.Lnext.Org == vStart)
          break;
          
        // Continue to next edge.
        eCur = eNext;
      }
      
      f = f.next;
    }
    
    return true;
  }

  // tessMeshCheckMesh( mesh ) checks a mesh for self-consistency.
  public function check():Void {
    var fHead = this.fHead;
    var vHead = this.vHead;
    var eHead = this.eHead;
    var f, fPrev, v, vPrev, e, ePrev;

    fPrev = fHead;
    while ((f = fPrev.next) != fHead) {
      Debug.assert(f.prev == fPrev);
      e = f.anEdge;
      do {
        Debug.assert(e.Sym != e);
        Debug.assert(e.Sym.Sym == e);
        Debug.assert(e.Lnext.Onext.Sym == e);
        Debug.assert(e.Onext.Sym.Lnext == e);
        Debug.assert(e.Lface == f);
        e = e.Lnext;
      } while (e != f.anEdge);
      fPrev = f;
    }
    Debug.assert(f.prev == fPrev && f.anEdge == null);

    vPrev = vHead;
    while ((v = vPrev.next) != vHead) {
      Debug.assert(v.prev == vPrev);
      e = v.anEdge;
      do {
        Debug.assert(e.Sym != e);
        Debug.assert(e.Sym.Sym == e);
        Debug.assert(e.Lnext.Onext.Sym == e);
        Debug.assert(e.Onext.Sym.Lnext == e);
        Debug.assert(e.Org == v);
        e = e.Onext;
      } while (e != v.anEdge);
      vPrev = v;
    }
    Debug.assert(v.prev == vPrev && v.anEdge == null);

    ePrev = eHead;
    while ((e = ePrev.next) != eHead) {
      Debug.assert(e.Sym.next == ePrev.Sym);
      Debug.assert(e.Sym != e);
      Debug.assert(e.Sym.Sym == e);
      Debug.assert(e.Org != null);
      Debug.assert(e.Dst != null);
      Debug.assert(e.Lnext.Onext.Sym == e);
      Debug.assert(e.Onext.Sym.Lnext == e);
      ePrev = e;
    }
    Debug.assert(e.Sym.next == ePrev.Sym
      && e.Sym == this.eHeadSym
      && e.Sym.Sym == e
      && e.Org == null && e.Dst == null
      && e.Lface == null && e.Rface == null);
  }
}

private class Geom
{
  static public function vertEq(u:TessVertex, v:TessVertex):Bool {
    return (u.s == v.s && u.t == v.t);
  }

  /* Returns TRUE if u is lexicographically <= v. */
  static public function vertLeq(u:TessVertex, v:TessVertex):Bool {
    return ((u.s < v.s) || (u.s == v.s && u.t <= v.t));
  }

  /* Versions of VertLeq, EdgeSign, EdgeEval with s and t transposed. */
  static public function transLeq(u:TessVertex, v:TessVertex):Bool {
    return ((u.t < v.t) || (u.t == v.t && u.s <= v.s));
  }

  static public function edgeGoesLeft(e:TessHalfEdge):Bool {
    return Geom.vertLeq(e.Dst, e.Org);
  }

  static public function edgeGoesRight(e:TessHalfEdge):Bool {
    return Geom.vertLeq(e.Org, e.Dst);
  }

  static public function edgeIsInternal(e:TessHalfEdge):Bool {
    return e.Rface != null && e.Rface.inside;
  }
  
  static public function vertL1dist(u:TessVertex, v:TessVertex):Float {
    return (Math.abs(u.s - v.s) + Math.abs(u.t - v.t));
  }

  //TESSreal tesedgeEval( TESSvertex *u, TESSvertex *v, TESSvertex *w )
  static public function edgeEval(u:TessVertex, v:TessVertex, w:TessVertex):Float {
    /* Given three vertices u,v,w such that VertLeq(u,v) && VertLeq(v,w),
    * evaluates the t-coord of the edge uw at the s-coord of the vertex v.
    * Returns v->t - (uw)(v->s), ie. the signed distance from uw to v.
    * If uw is vertical (and thus passes thru v), the result is zero.
    *
    * The calculation is extremely accurate and stable, even when v
    * is very close to u or w.  In particular if we set v->t = 0 and
    * let r be the negated result (this evaluates (uw)(v->s)), then
    * r is guaranteed to satisfy MIN(u->t,w->t) <= r <= MAX(u->t,w->t).
    */
    Debug.assert(Geom.vertLeq(u, v) && Geom.vertLeq(v, w));

    var gapL = v.s - u.s;
    var gapR = w.s - v.s;

    if (gapL + gapR > 0.0) {
      if (gapL < gapR) {
        return (v.t - u.t) + (u.t - w.t) * (gapL / (gapL + gapR));
      } else {
        return (v.t - w.t) + (w.t - u.t) * (gapR / (gapL + gapR));
      }
    }
    /* vertical line */
    return 0.0;
  }
  
  //TESSreal tesedgeSign( TESSvertex *u, TESSvertex *v, TESSvertex *w )
  static public function edgeSign(u:TessVertex, v:TessVertex, w:TessVertex):Float {
    /* Returns a number whose sign matches EdgeEval(u,v,w) but which
    * is cheaper to evaluate.  Returns > 0, == 0 , or < 0
    * as v is above, on, or below the edge uw.
    */
    Debug.assert(Geom.vertLeq(u, v) && Geom.vertLeq(v, w));

    var gapL = v.s - u.s;
    var gapR = w.s - v.s;

    if (gapL + gapR > 0.0) {
      return (v.t - w.t) * gapL + (v.t - u.t) * gapR;
    }
    /* vertical line */
    return 0.0;
  }


  /***********************************************************************
  * Define versions of EdgeSign, EdgeEval with s and t transposed.
  */

  //TESSreal testransEval( TESSvertex *u, TESSvertex *v, TESSvertex *w )
  static public function transEval(u:TessVertex, v:TessVertex, w:TessVertex):Float {
    /* Given three vertices u,v,w such that TransLeq(u,v) && TransLeq(v,w),
    * evaluates the t-coord of the edge uw at the s-coord of the vertex v.
    * Returns v->s - (uw)(v->t), ie. the signed distance from uw to v.
    * If uw is vertical (and thus passes thru v), the result is zero.
    *
    * The calculation is extremely accurate and stable, even when v
    * is very close to u or w.  In particular if we set v->s = 0 and
    * let r be the negated result (this evaluates (uw)(v->t)), then
    * r is guaranteed to satisfy MIN(u->s,w->s) <= r <= MAX(u->s,w->s).
    */
    Debug.assert(Geom.transLeq(u, v) && Geom.transLeq(v, w));

    var gapL = v.t - u.t;
    var gapR = w.t - v.t;

    if (gapL + gapR > 0.0) {
      if (gapL < gapR) {
        return (v.s - u.s) + (u.s - w.s) * (gapL / (gapL + gapR));
      } else {
        return (v.s - w.s) + (w.s - u.s) * (gapR / (gapL + gapR));
      }
    }
    /* vertical line */
    return 0.0;
  }
  
  //TESSreal testransSign( TESSvertex *u, TESSvertex *v, TESSvertex *w )
  static public function transSign(u:TessVertex, v:TessVertex, w:TessVertex):Float {
    /* Returns a number whose sign matches TransEval(u,v,w) but which
    * is cheaper to evaluate.  Returns > 0, == 0 , or < 0
    * as v is above, on, or below the edge uw.
    */
    Debug.assert(Geom.transLeq(u, v) && Geom.transLeq(v, w));

    var gapL = v.t - u.t;
    var gapR = w.t - v.t;

    if (gapL + gapR > 0.0) {
      return (v.s - w.s) * gapL + (v.s - u.s) * gapR;
    }
    /* vertical line */
    return 0.0;
  }

  //int tesvertCCW( TESSvertex *u, TESSvertex *v, TESSvertex *w )
  static public function vertCCW(u:TessVertex, v:TessVertex, w:TessVertex):Bool {
    /* For almost-degenerate situations, the results are not reliable.
    * Unless the floating-point arithmetic can be performed without
    * rounding errors, *any* implementation will give incorrect results
    * on some degenerate inputs, so the client must have some way to
    * handle this situation.
    */
    return (u.s*(v.t - w.t) + v.s*(w.t - u.t) + w.s*(u.t - v.t)) >= 0.0;
  }

  /* Given parameters a,x,b,y returns the value (b*x+a*y)/(a+b),
  * or (x+y)/2 if a==b==0.  It requires that a,b >= 0, and enforces
  * this in the rare case that one argument is slightly negative.
  * The implementation is extremely stable numerically.
  * In particular it guarantees that the result r satisfies
  * MIN(x,y) <= r <= MAX(x,y), and the results are very accurate
  * even when a and b differ greatly in magnitude.
  */
  static public function interpolate(a:Float, x:Float, b:Float, y:Float):Float {
    if (a < 0) a = 0;
    if (b < 0) b = 0;
    
    if (a <= b) {
      if (b == 0) return ((x+y) / 2);
      else return (x + (y-x) * (a/(a+b)));
    } else return (y + (x - y) * (b / (a + b)));
  }
  
  /*
  #ifndef FOR_TRITE_TEST_PROGRAM
  #define Interpolate(a,x,b,y)	RealInterpolate(a,x,b,y)
  #else

  // Claim: the ONLY property the sweep algorithm relies on is that
  // MIN(x,y) <= r <= MAX(x,y).  This is a nasty way to test that.
  #include <stdlib.h>
  extern int RandomInterpolate;

  double Interpolate( double a, double x, double b, double y)
  {
    printf("*********************%d\n",RandomInterpolate);
    if( RandomInterpolate ) {
      a = 1.2 * drand48() - 0.1;
      a = (a < 0) ? 0 : ((a > 1) ? 1 : a);
      b = 1.0 - a;
    }
    return RealInterpolate(a,x,b,y);
  }
  #endif*/

  static public function intersect(o1:TessVertex, d1:TessVertex, o2:TessVertex, d2:TessVertex, v:TessVertex):Void {
    /* Given edges (o1,d1) and (o2,d2), compute their point of intersection.
    * The computed point is guaranteed to lie in the intersection of the
    * bounding rectangles defined by each edge.
    */
    var z1, z2;
    var t;

    /* This is certainly not the most efficient way to find the intersection
    * of two line segments, but it is very numerically stable.
    *
    * Strategy: find the two middle vertices in the VertLeq ordering,
    * and interpolate the intersection s-value from these.  Then repeat
    * using the TransLeq ordering to find the intersection t-value.
    */

    if (!Geom.vertLeq(o1, d1)) { t = o1; o1 = d1; d1 = t; } //swap( o1, d1 ); }
    if (!Geom.vertLeq(o2, d2)) { t = o2; o2 = d2; d2 = t; } //swap( o2, d2 ); }
    if (!Geom.vertLeq(o1, o2)) { t = o1; o1 = o2; o2 = t; t = d1; d1 = d2; d2 = t; } //swap( o1, o2 ); swap( d1, d2 ); }

    if (!Geom.vertLeq(o2, d1)) {
      /* Technically, no intersection -- do our best */
      v.s = (o2.s + d1.s) / 2;
    } else if (Geom.vertLeq(d1, d2)) {
      /* Interpolate between o2 and d1 */
      z1 = Geom.edgeEval(o1, o2, d1);
      z2 = Geom.edgeEval(o2, d1, d2);
      if (z1 + z2 < 0) { z1 = -z1; z2 = -z2; }
      v.s = Geom.interpolate(z1, o2.s, z2, d1.s);
    } else {
      /* Interpolate between o2 and d2 */
      z1 = Geom.edgeSign(o1, o2, d1);
      z2 = -Geom.edgeSign(o1, d2, d1);
      if (z1 + z2 < 0) { z1 = -z1; z2 = -z2; }
      v.s = Geom.interpolate(z1, o2.s, z2, d2.s);
    }

    /* Now repeat the process for t */

    if (!Geom.transLeq(o1, d1)) { t = o1; o1 = d1; d1 = t; } //swap( o1, d1 ); }
    if (!Geom.transLeq(o2, d2)) { t = o2; o2 = d2; d2 = t; } //swap( o2, d2 ); }
    if (!Geom.transLeq(o1, o2)) { t = o1; o1 = o2; o2 = t; t = d1; d1 = d2; d2 = t; } //swap( o1, o2 ); swap( d1, d2 ); }

    if (!Geom.transLeq(o2, d1)) {
      /* Technically, no intersection -- do our best */
      v.t = (o2.t + d1.t) / 2;
    } else if (Geom.transLeq(d1, d2)) {
      /* Interpolate between o2 and d1 */
      z1 = Geom.transEval(o1, o2, d1);
      z2 = Geom.transEval(o2, d1, d2);
      if (z1 + z2 < 0) { z1 = -z1; z2 = -z2; }
      v.t = Geom.interpolate(z1, o2.t, z2, d1.t);
    } else {
      /* Interpolate between o2 and d2 */
      z1 = Geom.transSign(o1, o2, d1);
      z2 = -Geom.transSign(o1, d2, d1);
      if (z1 + z2 < 0) { z1 = -z1; z2 = -z2; }
      v.t = Geom.interpolate(z1, o2.t, z2, d2.t);
    }
  }
  
  /*
    Calculate the angle between v1-v2 and v1-v0
   */
  //TESSreal calcAngle( TESSvertex *v0, TESSvertex *v1, TESSvertex *v2 )
  static public function calcAngle(v0:TessVertex, v1:TessVertex, v2:TessVertex):Float
  {
    var num:Float, den:Float;
    var a = [v2.s - v1.s, v2.t - v1.t];
    var b = [v0.s - v1.s, v0.t - v1.t];
    num = a[0] * b[0] + a[1] * b[1];
    den = Math.sqrt(a[0] * a[0] + a[1] * a[1]) * Math.sqrt(b[0] * b[0] + b[1] * b[1]);
    if (den > 0.0) num /= den;
    if (num < -1.0) num = -1.0;
    if (num >  1.0) num =  1.0;
    return Math.acos(num);
  }

  /*
    Returns 1 is edge is locally delaunay
   */
  //int tesedgeIsLocallyDelaunay( TESShalfEdge *e )
  static public function edgeIsLocallyDelaunay(e:TessHalfEdge):Bool
  {
    return (calcAngle(e.Lnext.Org, e.Lnext.Lnext.Org, e.Org) +
        calcAngle(e.Sym.Lnext.Org, e.Sym.Lnext.Lnext.Org, e.Sym.Org)) < (Math.PI + 0.01);
  }
}

private class DictNode
{
  public var key:ActiveRegion = null;
  public var next:DictNode = null;
  public var prev:DictNode = null;	
  
  public function new() { }
}

private class Dict
{
  public var head:DictNode;
  public var frame:Tesselator;
  public var leq:Tesselator->ActiveRegion->ActiveRegion->Bool;
  
  public function new(frame:Tesselator, leq:Tesselator->ActiveRegion->ActiveRegion->Bool):Void 
  {
    this.head = new DictNode();
    this.head.next = this.head;
    this.head.prev = this.head;
    this.frame = frame;
    this.leq = leq;
  }
  
  public function min():DictNode {
    return this.head.next;
  }

  public function max():DictNode {
    return this.head.prev;
  }

  public function insert(k:ActiveRegion):DictNode {
    return this.insertBefore(this.head, k);
  }

  public function search(key:ActiveRegion):DictNode {
    /* Search returns the node with the smallest key greater than or equal
    * to the given key.  If there is no such key, returns a node whose
    * key is NULL.  Similarly, Succ(Max(d)) has a NULL key, etc.
    */
    var node = this.head;
    do {
      node = node.next;
    } while (node.key != null && !this.leq(this.frame, key, node.key));

    return node;
  }
  
  public function insertBefore(node:DictNode, key:ActiveRegion):DictNode {
    do {
      node = node.prev;
    } while (node.key != null && !this.leq(this.frame, node.key, key));

    var newNode = new DictNode();
    newNode.key = key;
    newNode.next = node.next;
    node.next.prev = newNode;
    newNode.prev = node;
    node.next = newNode;

    return newNode;
  }

  public function delete(node:DictNode):Void {
    node.next.prev = node.prev;
    node.prev.next = node.next;
  }
}

private class PQNode
{
  public var handle:Int = -1;
  
  public function new() { }
}

private class PQHandleElem
{
  public var key:TessVertex = null;
  public var node:Int = -1;
  
  public function new() { }
}

private class PriorityQ
{
  public var size:Int;
  public var max:Int;
  public var nodes:Array<PQNode>;
  public var handles:Array<PQHandleElem>;
  public var initialized:Bool;
  public var freeList:Int;
  public var leq:TessVertex->TessVertex->Bool;
  
  public function new(size:Int, leq:TessVertex->TessVertex->Bool) 
  {
    this.size = 0;
    this.max = size;

    this.nodes = [];
    for (i in 0...size + 1)
      this.nodes[i] = new PQNode();

    this.handles = [];
    for (i in 0...size + 1)
      this.handles[i] = new PQHandleElem();

    this.initialized = false;
    this.freeList = 0;
    this.leq = leq;

    this.nodes[1].handle = 1;	/* so that Minimum() returns NULL */
    this.handles[1].key = null;
  }
  
  private function floatDown_(curr:Int):Void
  {
    var n = this.nodes;
    var h = this.handles;
    var hCurr, hChild;
    var child;

    hCurr = n[curr].handle;
    while (true) {
      child = curr << 1;
      if (child < this.size && this.leq(h[n[child + 1].handle].key, h[n[child].handle].key)) {
        ++child;
      }

      Debug.assert(child <= this.max);

      hChild = n[child].handle;
      if (child > this.size || this.leq( h[hCurr].key, h[hChild].key)) {
        n[curr].handle = hCurr;
        h[hCurr].node = curr;
        break;
      }
      n[curr].handle = hChild;
      h[hChild].node = curr;
      curr = child;
    }
  }
  
  private function floatUp_(curr:Int):Void
  {
    var n = this.nodes;
    var h = this.handles;
    var hCurr, hParent;
    var parent;

    hCurr = n[curr].handle;
    while (true) {
      parent = curr >> 1;
      hParent = n[parent].handle;
      if (parent == 0 || this.leq(h[hParent].key, h[hCurr].key)) {
        n[curr].handle = hCurr;
        h[hCurr].node = curr;
        break;
      }
      n[curr].handle = hParent;
      h[hParent].node = curr;
      curr = parent;
    }
  }

  public function init():Void {
    /* This method of building a heap is O(n), rather than O(n lg n). */
    var i = this.size;
    while (i >= 1) {
      this.floatDown_(i);
      i--;
    }
    this.initialized = true;
  }
  
  public function min():TessVertex {
    return this.handles[this.nodes[1].handle].key;
  }

  public function isEmpty():Bool {
    return this.size == 0;
  }

  /* really pqHeapInsert */
  /* returns INV_HANDLE iff out of memory */
  //PQhandle pqHeapInsert( TESSalloc* alloc, PriorityQHeap *pq, PQkey keyNew )
  public function insert(keyNew:TessVertex):Int
  {
    var curr;
    var free;

    curr = ++this.size;
    if ((curr * 2) > this.max) {
      this.max *= 2;
      var s = this.nodes.length;
      for (i in s...this.max + 1)
        this.nodes[i] = new PQNode();

      s = this.handles.length;
      for (i in this.handles.length...this.max + 1)
        this.handles[i] = new PQHandleElem();
    }

    if (this.freeList == 0) {
      free = curr;
    } else {
      free = this.freeList;
      this.freeList = this.handles[free].node;
    }

    this.nodes[curr].handle = free;
    this.handles[free].node = curr;
    this.handles[free].key = keyNew;

    if (this.initialized) {
      this.floatUp_(curr);
    }
    return free;
  }

  //PQkey pqHeapExtractMin( PriorityQHeap *pq )
  public function extractMin():TessVertex {
    var n = this.nodes;
    var h = this.handles;
    var hMin = n[1].handle;
    var min = h[hMin].key;

    if (this.size > 0) {
      n[1].handle = n[this.size].handle;
      h[n[1].handle].node = 1;

      h[hMin].key = null;
      h[hMin].node = this.freeList;
      this.freeList = hMin;

      --this.size;
      if (this.size > 0) {
        this.floatDown_(1);
      }
    }
    return min;
  }

  public function delete(hCurr:Int):Void {
    var n = this.nodes;
    var h = this.handles;
    var curr;

    Debug.assert(hCurr >= 1 && hCurr <= this.max && h[hCurr].key != null);

    curr = h[hCurr].node;
    n[curr].handle = n[this.size].handle;
    h[n[curr].handle].node = curr;

    --this.size;
    if (curr <= this.size) {
      if (curr <= 1 || this.leq(h[n[curr>>1].handle].key, h[n[curr].handle].key)) {
        this.floatDown_(curr);
      } else {
        this.floatUp_(curr);
      }
    }
    h[hCurr].key = null;
    h[hCurr].node = this.freeList;
    this.freeList = hCurr;
  }
}

/* For each pair of adjacent edges crossing the sweep line, there is
* an ActiveRegion to represent the region between them.  The active
* regions are kept in sorted order in a dynamic dictionary.  As the
* sweep line crosses each vertex, we update the affected regions.
*/

private class ActiveRegion 
{
  public var eUp:TessHalfEdge = null;		/* upper edge, directed right to left */
  public var nodeUp:DictNode = null;		/* dictionary node corresponding to eUp */
  public var windingNumber:Int = 0;		/* used to determine which regions are
                      * inside the polygon */
  public var inside:Bool = false;			/* is this region inside the polygon? */
  public var sentinel:Bool = false;		/* marks fake edges at t = +/-infinity */
  public var dirty:Bool = false;			/* marks regions where the upper or lower
                      * edge has changed, but we haven't checked
                      * whether they intersect yet */
  public var fixUpperEdge:Bool = false;	/* marks temporary edges introduced when
                      * we process a "right vertex" (one without
                      * any edges leaving to the right) */
  
  public function new() { }
}

private class Sweep
{
  static public function regionBelow(r:ActiveRegion):ActiveRegion {
    return r.nodeUp.prev.key;
  }

  static public function regionAbove(r:ActiveRegion):ActiveRegion {
    return r.nodeUp.next.key;
  }

  static public function debugEvent(tess:Tesselator) {
    // empty
  }
  
  /*
  * Invariants for the Edge Dictionary.
  * - each pair of adjacent edges e2=Succ(e1) satisfies EdgeLeq(e1,e2)
  *   at any valid location of the sweep event
  * - if EdgeLeq(e2,e1) as well (at any valid sweep event), then e1 and e2
  *   share a common endpoint
  * - for each e, e->Dst has been processed, but not e->Org
  * - each edge e satisfies VertLeq(e->Dst,event) && VertLeq(event,e->Org)
  *   where "event" is the current sweep line event.
  * - no edge e has zero length
  *
  * Invariants for the Mesh (the processed portion).
  * - the portion of the mesh left of the sweep line is a planar graph,
  *   ie. there is *some* way to embed it in the plane
  * - no processed edge has zero length
  * - no two processed vertices have identical coordinates
  * - each "inside" region is monotone, ie. can be broken into two chains
  *   of monotonically increasing vertices according to VertLeq(v1,v2)
  *   - a non-invariant: these chains may intersect (very slightly)
  *
  * Invariants for the Sweep.
  * - if none of the edges incident to the event vertex have an activeRegion
  *   (ie. none of these edges are in the edge dictionary), then the vertex
  *   has only right-going edges.
  * - if an edge is marked "fixUpperEdge" (it is a temporary edge introduced
  *   by ConnectRightVertex), then it is the only right-going edge from
  *   its associated vertex.  (This says that these edges exist only
  *   when it is necessary.)
  */

  /* When we merge two edges into one, we need to compute the combined
  * winding of the new edge.
  */
  static public function addWinding(eDst:TessHalfEdge, eSrc:TessHalfEdge):Void {
    eDst.winding += eSrc.winding;
    eDst.Sym.winding += eSrc.Sym.winding;
  }

  //static int EdgeLeq( TESStesselator *tess, ActiveRegion *reg1, ActiveRegion *reg2 )
  static public function edgeLeq(tess:Tesselator, reg1:ActiveRegion, reg2:ActiveRegion):Bool {
    /*
    * Both edges must be directed from right to left (this is the canonical
    * direction for the upper edge of each region).
    *
    * The strategy is to evaluate a "t" value for each edge at the
    * current sweep line position, given by tess->event.  The calculations
    * are designed to be very stable, but of course they are not perfect.
    *
    * Special case: if both edge destinations are at the sweep event,
    * we sort the edges by slope (they would otherwise compare equally).
    */
    var ev = tess.event;
    var t1, t2;

    var e1 = reg1.eUp;
    var e2 = reg2.eUp;

    if (e1.Dst == ev) {
      if (e2.Dst == ev) {
        /* Two edges right of the sweep line which meet at the sweep event.
        * Sort them by slope.
        */
        if (Geom.vertLeq(e1.Org, e2.Org)) {
          return Geom.edgeSign(e2.Dst, e1.Org, e2.Org) <= 0;
        }
        return Geom.edgeSign(e1.Dst, e2.Org, e1.Org) >= 0;
      }
      return Geom.edgeSign(e2.Dst, ev, e2.Org) <= 0;
    }
    if (e2.Dst == ev) {
      return Geom.edgeSign(e1.Dst, ev, e1.Org) >= 0;
    }

    /* General case - compute signed distance *from* e1, e2 to event */
    var t1 = Geom.edgeEval(e1.Dst, ev, e1.Org);
    var t2 = Geom.edgeEval(e2.Dst, ev, e2.Org);
    return (t1 >= t2);
  }
  
  //static void DeleteRegion( TESStesselator *tess, ActiveRegion *reg )
  static public function deleteRegion(tess:Tesselator, reg:ActiveRegion):Void {
    if (reg.fixUpperEdge) {
      /* It was created with zero winding number, so it better be
      * deleted with zero winding number (ie. it better not get merged
      * with a real edge).
      */
      Debug.assert(reg.eUp.winding == 0);
    }
    reg.eUp.activeRegion = null;
    tess.dict.delete(reg.nodeUp);
  }

  //static int FixUpperEdge( TESStesselator *tess, ActiveRegion *reg, TESShalfEdge *newEdge )
  static public function fixUpperEdge(tess:Tesselator, reg:ActiveRegion, newEdge:TessHalfEdge):Void {
    /*
    * Replace an upper edge which needs fixing (see ConnectRightVertex).
    */
    Debug.assert(reg.fixUpperEdge);
    tess.mesh.delete(reg.eUp);
    reg.fixUpperEdge = false;
    reg.eUp = newEdge;
    newEdge.activeRegion = reg;
  }

  //static ActiveRegion *TopLeftRegion( TESStesselator *tess, ActiveRegion *reg )
  static public function topLeftRegion(tess:Tesselator, reg:ActiveRegion):ActiveRegion {
    var org = reg.eUp.Org;
    var e;

    /* Find the region above the uppermost edge with the same origin */
    do {
      reg = Sweep.regionAbove(reg);
    } while (reg.eUp.Org == org);

    /* If the edge above was a temporary edge introduced by ConnectRightVertex,
    * now is the time to fix it.
    */
    if (reg.fixUpperEdge) {
      e = tess.mesh.connect(Sweep.regionBelow(reg).eUp.Sym, reg.eUp.Lnext);
      if (e == null) return null;
      Sweep.fixUpperEdge(tess, reg, e);
      reg = Sweep.regionAbove(reg);
    }
    return reg;
  }
  
  //static ActiveRegion *TopRightRegion( ActiveRegion *reg )
  static public function topRightRegion(reg:ActiveRegion):ActiveRegion
  {
    var dst = reg.eUp.Dst;

    /* Find the region above the uppermost edge with the same destination */
    do {
      reg = Sweep.regionAbove(reg);
    } while (reg.eUp.Dst == dst);
    return reg;
  }

  //static ActiveRegion *AddRegionBelow( TESStesselator *tess, ActiveRegion *regAbove, TESShalfEdge *eNewUp )
  static public function addRegionBelow(tess:Tesselator, regAbove:ActiveRegion, eNewUp:TessHalfEdge):ActiveRegion {
    /*
    * Add a new active region to the sweep line, *somewhere* below "regAbove"
    * (according to where the new edge belongs in the sweep-line dictionary).
    * The upper edge of the new region will be "eNewUp".
    * Winding number and "inside" flag are not updated.
    */
    var regNew = new ActiveRegion();
    regNew.eUp = eNewUp;
    regNew.nodeUp = tess.dict.insertBefore(regAbove.nodeUp, regNew);
  //	if (regNew->nodeUp == NULL) longjmp(tess->env,1);
    regNew.fixUpperEdge = false;
    regNew.sentinel = false;
    regNew.dirty = false;

    eNewUp.activeRegion = regNew;
    return regNew;
  }
  
  //static int IsWindingInside( TESStesselator *tess, int n )
  static public function isWindingInside(tess:Tesselator, n:Int):Bool {
    switch (tess.windingRule) {
      case WindingRule.ODD:
        return (n & 1) != 0;
      case WindingRule.NON_ZERO:
        return (n != 0);
      case WindingRule.POSITIVE:
        return (n > 0);
      case WindingRule.NEGATIVE:
        return (n < 0);
      case WindingRule.ABS_GEQ_TWO:
        return (n >= 2) || (n <= -2);
    }
    Debug.assert(false);
    return false;
  }

  //static void ComputeWinding( TESStesselator *tess, ActiveRegion *reg )
  static public function computeWinding(tess:Tesselator, reg:ActiveRegion):Void {
    reg.windingNumber = Sweep.regionAbove(reg).windingNumber + reg.eUp.winding;
    reg.inside = Sweep.isWindingInside(tess, reg.windingNumber);
  }

  //static void FinishRegion( TESStesselator *tess, ActiveRegion *reg )
  static public function finishRegion(tess:Tesselator, reg:ActiveRegion):Void {
    /*
    * Delete a region from the sweep line.  This happens when the upper
    * and lower chains of a region meet (at a vertex on the sweep line).
    * The "inside" flag is copied to the appropriate mesh face (we could
    * not do this before -- since the structure of the mesh is always
    * changing, this face may not have even existed until now).
    */
    var e = reg.eUp;
    var f = e.Lface;

    f.inside = reg.inside;
    f.anEdge = e;   /* optimization for tessMeshTessellateMonoRegion() */
    Sweep.deleteRegion(tess, reg);
  }


  //static TESShalfEdge *FinishLeftRegions( TESStesselator *tess, ActiveRegion *regFirst, ActiveRegion *regLast )
  static public function finishLeftRegions(tess:Tesselator, regFirst:ActiveRegion, regLast:ActiveRegion):TessHalfEdge {
    /*
    * We are given a vertex with one or more left-going edges.  All affected
    * edges should be in the edge dictionary.  Starting at regFirst->eUp,
    * we walk down deleting all regions where both edges have the same
    * origin vOrg.  At the same time we copy the "inside" flag from the
    * active region to the face, since at this point each face will belong
    * to at most one region (this was not necessarily true until this point
    * in the sweep).  The walk stops at the region above regLast; if regLast
    * is NULL we walk as far as possible.  At the same time we relink the
    * mesh if necessary, so that the ordering of edges around vOrg is the
    * same as in the dictionary.
    */
    var e, ePrev;
    var reg = null;
    var regPrev = regFirst;
    var ePrev = regFirst.eUp;
    while (regPrev != regLast) {
      regPrev.fixUpperEdge = false;	/* placement was OK */
      reg = Sweep.regionBelow(regPrev);
      e = reg.eUp;
      if (e.Org != ePrev.Org) {
        if (!reg.fixUpperEdge) {
          /* Remove the last left-going edge.  Even though there are no further
          * edges in the dictionary with this origin, there may be further
          * such edges in the mesh (if we are adding left edges to a vertex
          * that has already been processed).  Thus it is important to call
          * FinishRegion rather than just DeleteRegion.
          */
          Sweep.finishRegion(tess, regPrev);
          break;
        }
        /* If the edge below was a temporary edge introduced by
        * ConnectRightVertex, now is the time to fix it.
        */
        e = tess.mesh.connect(ePrev.Lprev, e.Sym);
  //			if (e == NULL) longjmp(tess->env,1);
        Sweep.fixUpperEdge(tess, reg, e);
      }

      /* Relink edges so that ePrev->Onext == e */
      if (ePrev.Onext != e) {
        tess.mesh.splice(e.Oprev, e);
        tess.mesh.splice(ePrev, e);
      }
      Sweep.finishRegion(tess, regPrev);	/* may change reg->eUp */
      ePrev = reg.eUp;
      regPrev = reg;
    }
    return ePrev;
  }

  //static void AddRightEdges( TESStesselator *tess, ActiveRegion *regUp, TESShalfEdge *eFirst, TESShalfEdge *eLast, TESShalfEdge *eTopLeft, int cleanUp )
  static public function addRightEdges(tess:Tesselator, regUp:ActiveRegion, eFirst:TessHalfEdge, eLast:TessHalfEdge, eTopLeft:TessHalfEdge, cleanUp:Bool):Void {
    /*
    * Purpose: insert right-going edges into the edge dictionary, and update
    * winding numbers and mesh connectivity appropriately.  All right-going
    * edges share a common origin vOrg.  Edges are inserted CCW starting at
    * eFirst; the last edge inserted is eLast->Oprev.  If vOrg has any
    * left-going edges already processed, then eTopLeft must be the edge
    * such that an imaginary upward vertical segment from vOrg would be
    * contained between eTopLeft->Oprev and eTopLeft; otherwise eTopLeft
    * should be NULL.
    */
    var reg = null, regPrev;
    var e, ePrev;
    var firstTime = true;

    /* Insert the new right-going edges in the dictionary */
    e = eFirst;
    do {
      Debug.assert(Geom.vertLeq(e.Org, e.Dst));
      Sweep.addRegionBelow(tess, regUp, e.Sym);
      e = e.Onext;
    } while (e != eLast);

    /* Walk *all* right-going edges from e->Org, in the dictionary order,
    * updating the winding numbers of each region, and re-linking the mesh
    * edges to match the dictionary ordering (if necessary).
    */
    if (eTopLeft == null) {
      eTopLeft = Sweep.regionBelow(regUp).eUp.Rprev;
    }
    regPrev = regUp;
    ePrev = eTopLeft;
    while (true) {
      reg = Sweep.regionBelow(regPrev);
      e = reg.eUp.Sym;
      if (e.Org != ePrev.Org) break;

      if (e.Onext != ePrev) {
        /* Unlink e from its current position, and relink below ePrev */
        tess.mesh.splice(e.Oprev, e);
        tess.mesh.splice(ePrev.Oprev, e);
      }
      /* Compute the winding number and "inside" flag for the new regions */
      reg.windingNumber = regPrev.windingNumber - e.winding;
      reg.inside = Sweep.isWindingInside(tess, reg.windingNumber);

      /* Check for two outgoing edges with same slope -- process these
      * before any intersection tests (see example in tessComputeInterior).
      */
      regPrev.dirty = true;
      if (!firstTime && Sweep.checkForRightSplice(tess, regPrev)) {
        Sweep.addWinding(e, ePrev);
        Sweep.deleteRegion(tess, regPrev);
        tess.mesh.delete(ePrev);
      }
      firstTime = false;
      regPrev = reg;
      ePrev = e;
    }
    regPrev.dirty = true;
    Debug.assert((regPrev.windingNumber - e.winding) == reg.windingNumber);

    if (cleanUp) {
      /* Check for intersections between newly adjacent edges. */
      Sweep.walkDirtyRegions(tess, regPrev);
    }
  }

  //static void SpliceMergeVertices( TESStesselator *tess, TESShalfEdge *e1, TESShalfEdge *e2 )
  static public function spliceMergeVertices(tess:Tesselator, e1:TessHalfEdge, e2:TessHalfEdge):Void {
    /*
    * Two vertices with idential coordinates are combined into one.
    * e1->Org is kept, while e2->Org is discarded.
    */
    tess.mesh.splice(e1, e2); 
  }

  //static void VertexWeights( TESSvertex *isect, TESSvertex *org, TESSvertex *dst, TESSreal *weights )
  static public function vertexWeights(isect:TessVertex, org:TessVertex, dst:TessVertex):Void {
    /*
    * Find some weights which describe how the intersection vertex is
    * a linear combination of "org" and "dest".  Each of the two edges
    * which generated "isect" is allocated 50% of the weight; each edge
    * splits the weight between its org and dst according to the
    * relative distance to "isect".
    */
    var t1 = Geom.vertL1dist(org,isect);
    var t2 = Geom.vertL1dist(dst, isect);
    var w0 = 0.5 * t2 / (t1 + t2);
    var w1 = 0.5 * t1 / (t1 + t2);
    isect.coords[0] += w0 * org.coords[0] + w1 * dst.coords[0];
    isect.coords[1] += w0 * org.coords[1] + w1 * dst.coords[1];
    isect.coords[2] += w0 * org.coords[2] + w1 * dst.coords[2];
  }
  
  //static void GetIntersectData( TESStesselator *tess, TESSvertex *isect, TESSvertex *orgUp, TESSvertex *dstUp, TESSvertex *orgLo, TESSvertex *dstLo )
  static public function getIntersectData(tess:Tesselator, isect:TessVertex, orgUp:TessVertex, dstUp:TessVertex, orgLo:TessVertex, dstLo:TessVertex):Void {
     /*
     * We've computed a new intersection point, now we need a "data" pointer
     * from the user so that we can refer to this new vertex in the
     * rendering callbacks.
     */
    isect.coords[0] = isect.coords[1] = isect.coords[2] = 0;
    isect.idx = -1;
    Sweep.vertexWeights(isect, orgUp, dstUp);
    Sweep.vertexWeights(isect, orgLo, dstLo);
  }

  //static int CheckForRightSplice( TESStesselator *tess, ActiveRegion *regUp )
  static public function checkForRightSplice(tess:Tesselator, regUp:ActiveRegion):Bool {
    /*
    * Check the upper and lower edge of "regUp", to make sure that the
    * eUp->Org is above eLo, or eLo->Org is below eUp (depending on which
    * origin is leftmost).
    *
    * The main purpose is to splice right-going edges with the same
    * dest vertex and nearly identical slopes (ie. we can't distinguish
    * the slopes numerically).  However the splicing can also help us
    * to recover from numerical errors.  For example, suppose at one
    * point we checked eUp and eLo, and decided that eUp->Org is barely
    * above eLo.  Then later, we split eLo into two edges (eg. from
    * a splice operation like this one).  This can change the result of
    * our test so that now eUp->Org is incident to eLo, or barely below it.
    * We must correct this condition to maintain the dictionary invariants.
    *
    * One possibility is to check these edges for intersection again
    * (ie. CheckForIntersect).  This is what we do if possible.  However
    * CheckForIntersect requires that tess->event lies between eUp and eLo,
    * so that it has something to fall back on when the intersection
    * calculation gives us an unusable answer.  So, for those cases where
    * we can't check for intersection, this routine fixes the problem
    * by just splicing the offending vertex into the other edge.
    * This is a guaranteed solution, no matter how degenerate things get.
    * Basically this is a combinatorial solution to a numerical problem.
    */
    var regLo = Sweep.regionBelow(regUp);
    var eUp = regUp.eUp;
    var eLo = regLo.eUp;

    if (Geom.vertLeq(eUp.Org, eLo.Org)) {
      if (Geom.edgeSign(eLo.Dst, eUp.Org, eLo.Org) > 0) return false;

      /* eUp->Org appears to be below eLo */
      if (!Geom.vertEq(eUp.Org, eLo.Org)) {
        /* Splice eUp->Org into eLo */
        tess.mesh.splitEdge(eLo.Sym);
        tess.mesh.splice(eUp, eLo.Oprev);
        regUp.dirty = regLo.dirty = true;

      } else if (eUp.Org != eLo.Org) {
        /* merge the two vertices, discarding eUp->Org */
        tess.pq.delete(eUp.Org.pqHandle);
        Sweep.spliceMergeVertices(tess, eLo.Oprev, eUp);
      }
    } else {
      if (Geom.edgeSign(eUp.Dst, eLo.Org, eUp.Org) < 0) return false;

      /* eLo->Org appears to be above eUp, so splice eLo->Org into eUp */
      Sweep.regionAbove(regUp).dirty = regUp.dirty = true;
      tess.mesh.splitEdge(eUp.Sym);
      tess.mesh.splice(eLo.Oprev, eUp);
    }
    return true;
  }

  //static int CheckForLeftSplice( TESStesselator *tess, ActiveRegion *regUp )
  static public function checkForLeftSplice(tess:Tesselator, regUp:ActiveRegion):Bool {
    /*
    * Check the upper and lower edge of "regUp", to make sure that the
    * eUp->Dst is above eLo, or eLo->Dst is below eUp (depending on which
    * destination is rightmost).
    *
    * Theoretically, this should always be true.  However, splitting an edge
    * into two pieces can change the results of previous tests.  For example,
    * suppose at one point we checked eUp and eLo, and decided that eUp->Dst
    * is barely above eLo.  Then later, we split eLo into two edges (eg. from
    * a splice operation like this one).  This can change the result of
    * the test so that now eUp->Dst is incident to eLo, or barely below it.
    * We must correct this condition to maintain the dictionary invariants
    * (otherwise new edges might get inserted in the wrong place in the
    * dictionary, and bad stuff will happen).
    *
    * We fix the problem by just splicing the offending vertex into the
    * other edge.
    */
    var regLo = Sweep.regionBelow(regUp);
    var eUp = regUp.eUp;
    var eLo = regLo.eUp;
    var e;

    Debug.assert(!Geom.vertEq(eUp.Dst, eLo.Dst));

    if (Geom.vertLeq(eUp.Dst, eLo.Dst)) {
      if (Geom.edgeSign(eUp.Dst, eLo.Dst, eUp.Org) < 0 ) return false;

      /* eLo->Dst is above eUp, so splice eLo->Dst into eUp */
      Sweep.regionAbove(regUp).dirty = regUp.dirty = true;
      e = tess.mesh.splitEdge(eUp);
      tess.mesh.splice(eLo.Sym, e);
      e.Lface.inside = regUp.inside;
    } else {
      if (Geom.edgeSign(eLo.Dst, eUp.Dst, eLo.Org) > 0) return false;

      /* eUp->Dst is below eLo, so splice eUp->Dst into eLo */
      regUp.dirty = regLo.dirty = true;
      e = tess.mesh.splitEdge(eLo);
      tess.mesh.splice(eUp.Lnext, eLo.Sym);
      e.Rface.inside = regUp.inside;
    }
    return true;
  }


  //static int CheckForIntersect( TESStesselator *tess, ActiveRegion *regUp )
  static public function checkForIntersect(tess:Tesselator, regUp:ActiveRegion):Bool {
    /*
    * Check the upper and lower edges of the given region to see if
    * they intersect.  If so, create the intersection and add it
    * to the data structures.
    *
    * Returns TRUE if adding the new intersection resulted in a recursive
    * call to AddRightEdges(); in this case all "dirty" regions have been
    * checked for intersections, and possibly regUp has been deleted.
    */
    var regLo = Sweep.regionBelow(regUp);
    var eUp = regUp.eUp;
    var eLo = regLo.eUp;
    var orgUp = eUp.Org;
    var orgLo = eLo.Org;
    var dstUp = eUp.Dst;
    var dstLo = eLo.Dst;
    var tMinUp, tMaxLo;
    var isect = new TessVertex(), orgMin;
    var e;

    Debug.assert(!Geom.vertEq(dstLo, dstUp));
    Debug.assert(Geom.edgeSign(dstUp, tess.event, orgUp) <= 0);
    Debug.assert(Geom.edgeSign(dstLo, tess.event, orgLo) >= 0);
    Debug.assert(orgUp != tess.event && orgLo != tess.event);
    Debug.assert(!regUp.fixUpperEdge && !regLo.fixUpperEdge);

    if (orgUp == orgLo) return false;	/* right endpoints are the same */

    tMinUp = Math.min(orgUp.t, dstUp.t);
    tMaxLo = Math.max(orgLo.t, dstLo.t);
    if (tMinUp > tMaxLo) return false;	/* t ranges do not overlap */

    if (Geom.vertLeq(orgUp, orgLo)) {
      if (Geom.edgeSign(dstLo, orgUp, orgLo) > 0) return false;
    } else {
      if (Geom.edgeSign(dstUp, orgLo, orgUp) < 0) return false;
    }

    /* At this point the edges intersect, at least marginally */
    Sweep.debugEvent(tess);

    Geom.intersect(dstUp, orgUp, dstLo, orgLo, isect);
    /* The following properties are guaranteed: */
    Debug.assert(Math.min(orgUp.t, dstUp.t) <= isect.t);
    Debug.assert(isect.t <= Math.max(orgLo.t, dstLo.t));
    Debug.assert(Math.min(dstLo.s, dstUp.s) <= isect.s);
    Debug.assert(isect.s <= Math.max(orgLo.s, orgUp.s));

    if (Geom.vertLeq(isect, tess.event)) {
      /* The intersection point lies slightly to the left of the sweep line,
      * so move it until it''s slightly to the right of the sweep line.
      * (If we had perfect numerical precision, this would never happen
      * in the first place).  The easiest and safest thing to do is
      * replace the intersection by tess->event.
      */
      isect.s = tess.event.s;
      isect.t = tess.event.t;
    }
    /* Similarly, if the computed intersection lies to the right of the
    * rightmost origin (which should rarely happen), it can cause
    * unbelievable inefficiency on sufficiently degenerate inputs.
    * (If you have the test program, try running test54.d with the
    * "X zoom" option turned on).
    */
    orgMin = Geom.vertLeq(orgUp, orgLo) ? orgUp : orgLo;
    if (Geom.vertLeq(orgMin, isect)) {
      isect.s = orgMin.s;
      isect.t = orgMin.t;
    }

    if (Geom.vertEq(isect, orgUp) || Geom.vertEq(isect, orgLo)) {
      /* Easy case -- intersection at one of the right endpoints */
      Sweep.checkForRightSplice(tess, regUp);
      return false;
    }

    if ((!Geom.vertEq(dstUp, tess.event)
      && Geom.edgeSign(dstUp, tess.event, isect) >= 0)
      || (!Geom.vertEq(dstLo, tess.event)
      && Geom.edgeSign(dstLo, tess.event, isect) <= 0))
    {
      /* Very unusual -- the new upper or lower edge would pass on the
      * wrong side of the sweep event, or through it.  This can happen
      * due to very small numerical errors in the intersection calculation.
      */
      if (dstLo == tess.event) {
        /* Splice dstLo into eUp, and process the new region(s) */
        tess.mesh.splitEdge(eUp.Sym);
        tess.mesh.splice(eLo.Sym, eUp);
        regUp = Sweep.topLeftRegion(tess, regUp);
  //			if (regUp == NULL) longjmp(tess->env,1);
        eUp = Sweep.regionBelow(regUp).eUp;
        Sweep.finishLeftRegions(tess, Sweep.regionBelow(regUp), regLo);
        Sweep.addRightEdges(tess, regUp, eUp.Oprev, eUp, eUp, true);
        return true;
      }
      if (dstUp == tess.event) {
        /* Splice dstUp into eLo, and process the new region(s) */
        tess.mesh.splitEdge(eLo.Sym);
        tess.mesh.splice(eUp.Lnext, eLo.Oprev); 
        regLo = regUp;
        regUp = Sweep.topRightRegion(regUp);
        e = Sweep.regionBelow(regUp).eUp.Rprev;
        regLo.eUp = eLo.Oprev;
        eLo = Sweep.finishLeftRegions(tess, regLo, null);
        Sweep.addRightEdges(tess, regUp, eLo.Onext, eUp.Rprev, e, true);
        return true;
      }
      /* Special case: called from ConnectRightVertex.  If either
      * edge passes on the wrong side of tess->event, split it
      * (and wait for ConnectRightVertex to splice it appropriately).
      */
      if (Geom.edgeSign(dstUp, tess.event, isect) >= 0) {
        Sweep.regionAbove(regUp).dirty = regUp.dirty = true;
        tess.mesh.splitEdge(eUp.Sym);
        eUp.Org.s = tess.event.s;
        eUp.Org.t = tess.event.t;
      }
      if (Geom.edgeSign(dstLo, tess.event, isect) <= 0) {
        regUp.dirty = regLo.dirty = true;
        tess.mesh.splitEdge(eLo.Sym);
        eLo.Org.s = tess.event.s;
        eLo.Org.t = tess.event.t;
      }
      /* leave the rest for ConnectRightVertex */
      return false;
    }

    /* General case -- split both edges, splice into new vertex.
    * When we do the splice operation, the order of the arguments is
    * arbitrary as far as correctness goes.  However, when the operation
    * creates a new face, the work done is proportional to the size of
    * the new face.  We expect the faces in the processed part of
    * the mesh (ie. eUp->Lface) to be smaller than the faces in the
    * unprocessed original contours (which will be eLo->Oprev->Lface).
    */
    tess.mesh.splitEdge(eUp.Sym);
    tess.mesh.splitEdge(eLo.Sym);
    tess.mesh.splice(eLo.Oprev, eUp);
    eUp.Org.s = isect.s;
    eUp.Org.t = isect.t;
    eUp.Org.pqHandle = tess.pq.insert(eUp.Org);
    Sweep.getIntersectData(tess, eUp.Org, orgUp, dstUp, orgLo, dstLo);
    Sweep.regionAbove(regUp).dirty = regUp.dirty = regLo.dirty = true;
    return false;
  }
  
  //static void WalkDirtyRegions( TESStesselator *tess, ActiveRegion *regUp )
  static public function walkDirtyRegions(tess:Tesselator, regUp:ActiveRegion):Void {
    /*
    * When the upper or lower edge of any region changes, the region is
    * marked "dirty".  This routine walks through all the dirty regions
    * and makes sure that the dictionary invariants are satisfied
    * (see the comments at the beginning of this file).  Of course
    * new dirty regions can be created as we make changes to restore
    * the invariants.
    */
    var regLo = Sweep.regionBelow(regUp);
    var eUp, eLo;

    while (true) {
      /* Find the lowest dirty region (we walk from the bottom up). */
      while (regLo.dirty) {
        regUp = regLo;
        regLo = Sweep.regionBelow(regLo);
      }
      if (!regUp.dirty) {
        regLo = regUp;
        regUp = Sweep.regionAbove(regUp);
        if (regUp == null || !regUp.dirty) {
          /* We've walked all the dirty regions */
          return;
        }
      }
      regUp.dirty = false;
      eUp = regUp.eUp;
      eLo = regLo.eUp;

      if (eUp.Dst != eLo.Dst) {
        /* Check that the edge ordering is obeyed at the Dst vertices. */
        if (Sweep.checkForLeftSplice(tess, regUp)) {

          /* If the upper or lower edge was marked fixUpperEdge, then
          * we no longer need it (since these edges are needed only for
          * vertices which otherwise have no right-going edges).
          */
          if (regLo.fixUpperEdge) {
            Sweep.deleteRegion(tess, regLo);
            tess.mesh.delete(eLo);
            regLo = Sweep.regionBelow(regUp);
            eLo = regLo.eUp;
          } else if (regUp.fixUpperEdge) {
            Sweep.deleteRegion(tess, regUp);
            tess.mesh.delete(eUp);
            regUp = Sweep.regionAbove(regLo);
            eUp = regUp.eUp;
          }
        }
      }
      if (eUp.Org != eLo.Org) {
        if (eUp.Dst != eLo.Dst
          && !regUp.fixUpperEdge && !regLo.fixUpperEdge
          && (eUp.Dst == tess.event || eLo.Dst == tess.event))
        {
          /* When all else fails in CheckForIntersect(), it uses tess->event
          * as the intersection location.  To make this possible, it requires
          * that tess->event lie between the upper and lower edges, and also
          * that neither of these is marked fixUpperEdge (since in the worst
          * case it might splice one of these edges into tess->event, and
          * violate the invariant that fixable edges are the only right-going
          * edge from their associated vertex).
          */
          if (Sweep.checkForIntersect(tess, regUp)) {
            /* WalkDirtyRegions() was called recursively; we're done */
            return;
          }
        } else {
          /* Even though we can't use CheckForIntersect(), the Org vertices
          * may violate the dictionary edge ordering.  Check and correct this.
          */
          Sweep.checkForRightSplice(tess, regUp);
        }
      }
      if (eUp.Org == eLo.Org && eUp.Dst == eLo.Dst) {
        /* A degenerate loop consisting of only two edges -- delete it. */
        Sweep.addWinding(eLo, eUp);
        Sweep.deleteRegion(tess, regUp);
        tess.mesh.delete(eUp);
        regUp = Sweep.regionAbove(regLo);
      }
    }
  }

  //static void ConnectRightVertex( TESStesselator *tess, ActiveRegion *regUp, TESShalfEdge *eBottomLeft )
  static public function connectRightVertex(tess:Tesselator, regUp:ActiveRegion, eBottomLeft:TessHalfEdge):Void {
    /*
    * Purpose: connect a "right" vertex vEvent (one where all edges go left)
    * to the unprocessed portion of the mesh.  Since there are no right-going
    * edges, two regions (one above vEvent and one below) are being merged
    * into one.  "regUp" is the upper of these two regions.
    *
    * There are two reasons for doing this (adding a right-going edge):
    *  - if the two regions being merged are "inside", we must add an edge
    *    to keep them separated (the combined region would not be monotone).
    *  - in any case, we must leave some record of vEvent in the dictionary,
    *    so that we can merge vEvent with features that we have not seen yet.
    *    For example, maybe there is a vertical edge which passes just to
    *    the right of vEvent; we would like to splice vEvent into this edge.
    *
    * However, we don't want to connect vEvent to just any vertex.  We don''t
    * want the new edge to cross any other edges; otherwise we will create
    * intersection vertices even when the input data had no self-intersections.
    * (This is a bad thing; if the user's input data has no intersections,
    * we don't want to generate any false intersections ourselves.)
    *
    * Our eventual goal is to connect vEvent to the leftmost unprocessed
    * vertex of the combined region (the union of regUp and regLo).
    * But because of unseen vertices with all right-going edges, and also
    * new vertices which may be created by edge intersections, we don''t
    * know where that leftmost unprocessed vertex is.  In the meantime, we
    * connect vEvent to the closest vertex of either chain, and mark the region
    * as "fixUpperEdge".  This flag says to delete and reconnect this edge
    * to the next processed vertex on the boundary of the combined region.
    * Quite possibly the vertex we connected to will turn out to be the
    * closest one, in which case we won''t need to make any changes.
    */
    var eNew;
    var eTopLeft = eBottomLeft.Onext;
    var regLo = Sweep.regionBelow(regUp);
    var eUp = regUp.eUp;
    var eLo = regLo.eUp;
    var degenerate = false;

    if (eUp.Dst != eLo.Dst) {
      Sweep.checkForIntersect(tess, regUp);
    }

    /* Possible new degeneracies: upper or lower edge of regUp may pass
    * through vEvent, or may coincide with new intersection vertex
    */
    if (Geom.vertEq(eUp.Org, tess.event)) {
      tess.mesh.splice(eTopLeft.Oprev, eUp);
      regUp = Sweep.topLeftRegion(tess, regUp);
      eTopLeft = Sweep.regionBelow(regUp).eUp;
      Sweep.finishLeftRegions(tess, Sweep.regionBelow(regUp), regLo);
      degenerate = true;
    }
    if (Geom.vertEq(eLo.Org, tess.event)) {
      tess.mesh.splice(eBottomLeft, eLo.Oprev);
      eBottomLeft = Sweep.finishLeftRegions(tess, regLo, null);
      degenerate = true;
    }
    if (degenerate) {
      Sweep.addRightEdges(tess, regUp, eBottomLeft.Onext, eTopLeft, eTopLeft, true);
      return;
    }

    /* Non-degenerate situation -- need to add a temporary, fixable edge.
    * Connect to the closer of eLo->Org, eUp->Org.
    */
    if (Geom.vertLeq(eLo.Org, eUp.Org)) {
      eNew = eLo.Oprev;
    } else {
      eNew = eUp;
    }
    eNew = tess.mesh.connect(eBottomLeft.Lprev, eNew);

    /* Prevent cleanup, otherwise eNew might disappear before we've even
    * had a chance to mark it as a temporary edge.
    */
    Sweep.addRightEdges(tess, regUp, eNew, eNew.Onext, eNew.Onext, false);
    eNew.Sym.activeRegion.fixUpperEdge = true;
    Sweep.walkDirtyRegions(tess, regUp);
  }
  
  /* Because vertices at exactly the same location are merged together
  * before we process the sweep event, some degenerate cases can't occur.
  * However if someone eventually makes the modifications required to
  * merge features which are close together, the cases below marked
  * TOLERANCE_NONZERO will be useful.  They were debugged before the
  * code to merge identical vertices in the main loop was added.
  */
  //#define TOLERANCE_NONZERO	FALSE

  //static void ConnectLeftDegenerate( TESStesselator *tess, ActiveRegion *regUp, TESSvertex *vEvent )
  static public function connectLeftDegenerate(tess:Tesselator, regUp:ActiveRegion, vEvent:TessVertex):Void {
    /*
    * The event vertex lies exacty on an already-processed edge or vertex.
    * Adding the new vertex involves splicing it into the already-processed
    * part of the mesh.
    */
    var e, eTopLeft, eTopRight, eLast;
    var reg;

    e = regUp.eUp;
    if (Geom.vertEq(e.Org, vEvent)) {
      /* e->Org is an unprocessed vertex - just combine them, and wait
      * for e->Org to be pulled from the queue
      */
      Debug.assert(false /*TOLERANCE_NONZERO*/);
      Sweep.spliceMergeVertices(tess, e, vEvent.anEdge);
      return;
    }

    if (!Geom.vertEq(e.Dst, vEvent)) {
      /* General case -- splice vEvent into edge e which passes through it */
      tess.mesh.splitEdge(e.Sym);
      if (regUp.fixUpperEdge) {
        /* This edge was fixable -- delete unused portion of original edge */
        tess.mesh.delete(e.Onext);
        regUp.fixUpperEdge = false;
      }
      tess.mesh.splice(vEvent.anEdge, e);
      Sweep.sweepEvent(tess, vEvent);	/* recurse */
      return;
    }

    /* vEvent coincides with e->Dst, which has already been processed.
    * Splice in the additional right-going edges.
    */
    Debug.assert(false /*TOLERANCE_NONZERO*/);
    regUp = Sweep.topRightRegion(regUp);
    reg = Sweep.regionBelow(regUp);
    eTopRight = reg.eUp.Sym;
    eTopLeft = eLast = eTopRight.Onext;
    if (reg.fixUpperEdge) {
      /* Here e->Dst has only a single fixable edge going right.
      * We can delete it since now we have some real right-going edges.
      */
      Debug.assert(eTopLeft != eTopRight);   /* there are some left edges too */
      Sweep.deleteRegion(tess, reg);
      tess.mesh.delete(eTopRight);
      eTopRight = eTopLeft.Oprev;
    }
    tess.mesh.splice(vEvent.anEdge, eTopRight);
    if(!Geom.edgeGoesLeft(eTopLeft)) {
      /* e->Dst had no left-going edges -- indicate this to AddRightEdges() */
      eTopLeft = null;
    }
    Sweep.addRightEdges(tess, regUp, eTopRight.Onext, eLast, eTopLeft, true);
  }


  //static void ConnectLeftVertex( TESStesselator *tess, TESSvertex *vEvent )
  static public function connectLeftVertex(tess:Tesselator, vEvent:TessVertex):Void {
    /*
    * Purpose: connect a "left" vertex (one where both edges go right)
    * to the processed portion of the mesh.  Let R be the active region
    * containing vEvent, and let U and L be the upper and lower edge
    * chains of R.  There are two possibilities:
    *
    * - the normal case: split R into two regions, by connecting vEvent to
    *   the rightmost vertex of U or L lying to the left of the sweep line
    *
    * - the degenerate case: if vEvent is close enough to U or L, we
    *   merge vEvent into that edge chain.  The subcases are:
    *	- merging with the rightmost vertex of U or L
    *	- merging with the active edge of U or L
    *	- merging with an already-processed portion of U or L
    */
    var regUp, regLo, reg;
    var eUp, eLo, eNew;
    var tmp = new ActiveRegion();

    /* assert( vEvent->anEdge->Onext->Onext == vEvent->anEdge ); */

    /* Get a pointer to the active region containing vEvent */
    tmp.eUp = vEvent.anEdge.Sym;
    /* __GL_DICTLISTKEY */ /* tessDictListSearch */
    regUp = tess.dict.search(tmp).key;
    regLo = Sweep.regionBelow(regUp);
    if (regLo == null) {
      // This may happen if the input polygon is coplanar.
      return;
    }
    eUp = regUp.eUp;
    eLo = regLo.eUp;

    /* Try merging with U or L first */
    if (Geom.edgeSign(eUp.Dst, vEvent, eUp.Org) == 0.0) {
      Sweep.connectLeftDegenerate(tess, regUp, vEvent);
      return;
    }

    /* Connect vEvent to rightmost processed vertex of either chain.
    * e->Dst is the vertex that we will connect to vEvent.
    */
    reg = Geom.vertLeq(eLo.Dst, eUp.Dst) ? regUp : regLo;

    if (regUp.inside || reg.fixUpperEdge) {
      if (reg == regUp) {
        eNew = tess.mesh.connect(vEvent.anEdge.Sym, eUp.Lnext);
      } else {
        var tempHalfEdge = tess.mesh.connect(eLo.Dnext, vEvent.anEdge);
        eNew = tempHalfEdge.Sym;
      }
      if (reg.fixUpperEdge) {
        Sweep.fixUpperEdge(tess, reg, eNew);
      } else {
        Sweep.computeWinding(tess, Sweep.addRegionBelow(tess, regUp, eNew));
      }
      Sweep.sweepEvent(tess, vEvent);
    } else {
      /* The new vertex is in a region which does not belong to the polygon.
      * We don''t need to connect this vertex to the rest of the mesh.
      */
      Sweep.addRightEdges(tess, regUp, vEvent.anEdge, vEvent.anEdge, null, true);
    }
  };

  //static void SweepEvent( TESStesselator *tess, TESSvertex *vEvent )
  static public function sweepEvent(tess:Tesselator, vEvent:TessVertex):Void {
    /*
    * Does everything necessary when the sweep line crosses a vertex.
    * Updates the mesh and the edge dictionary.
    */

    tess.event = vEvent;		/* for access in EdgeLeq() */
    Sweep.debugEvent(tess);

    /* Check if this vertex is the right endpoint of an edge that is
    * already in the dictionary.  In this case we don't need to waste
    * time searching for the location to insert new edges.
    */
    var e = vEvent.anEdge;
    while (e.activeRegion == null) {
      e = e.Onext;
      if (e == vEvent.anEdge) {
        /* All edges go right -- not incident to any processed edges */
        Sweep.connectLeftVertex(tess, vEvent);
        return;
      }
    }

    /* Processing consists of two phases: first we "finish" all the
    * active regions where both the upper and lower edges terminate
    * at vEvent (ie. vEvent is closing off these regions).
    * We mark these faces "inside" or "outside" the polygon according
    * to their winding number, and delete the edges from the dictionary.
    * This takes care of all the left-going edges from vEvent.
    */
    var regUp = Sweep.topLeftRegion(tess, e.activeRegion);
    Debug.assert(regUp != null);
  //	if (regUp == NULL) longjmp(tess->env,1);
    var reg = Sweep.regionBelow(regUp);
    var eTopLeft = reg.eUp;
    var eBottomLeft = Sweep.finishLeftRegions(tess, reg, null);

    /* Next we process all the right-going edges from vEvent.  This
    * involves adding the edges to the dictionary, and creating the
    * associated "active regions" which record information about the
    * regions between adjacent dictionary edges.
    */
    if (eBottomLeft.Onext == eTopLeft) {
      /* No right-going edges -- add a temporary "fixable" edge */
      Sweep.connectRightVertex(tess, regUp, eBottomLeft);
    } else {
      Sweep.addRightEdges(tess, regUp, eBottomLeft.Onext, eTopLeft, eTopLeft, true);
    }
  }

  /* Make the sentinel coordinates big enough that they will never be
  * merged with real input features.
  */

  //static void AddSentinel( TESStesselator *tess, TESSreal smin, TESSreal smax, TESSreal t )
  static public function addSentinel(tess:Tesselator, smin:Float, smax:Float, t:Float):Void {
    /*
    * We add two sentinel edges above and below all other edges,
    * to avoid special cases at the top and bottom.
    */
    var reg = new ActiveRegion();
    var e = tess.mesh.makeEdge();
  //	if (e == NULL) longjmp(tess->env,1);

    e.Org.s = smax;
    e.Org.t = t;
    e.Dst.s = smin;
    e.Dst.t = t;
    tess.event = e.Dst;		/* initialize it */

    reg.eUp = e;
    reg.windingNumber = 0;
    reg.inside = false;
    reg.fixUpperEdge = false;
    reg.sentinel = true;
    reg.dirty = false;
    reg.nodeUp = tess.dict.insert(reg);
  //	if (reg->nodeUp == NULL) longjmp(tess->env,1);
  }
  
  //static void InitEdgeDict( TESStesselator *tess )
  static public function initEdgeDict(tess:Tesselator):Void {
    /*
    * We maintain an ordering of edge intersections with the sweep line.
    * This order is maintained in a dynamic dictionary.
    */
    tess.dict = new Dict(tess, Sweep.edgeLeq);
  //	if (tess->dict == NULL) longjmp(tess->env,1);

    var w = (tess.bmax[0] - tess.bmin[0]);
    var h = (tess.bmax[1] - tess.bmin[1]);

    var smin = tess.bmin[0] - w;
    var smax = tess.bmax[0] + w;
    var tmin = tess.bmin[1] - h;
    var tmax = tess.bmax[1] + h;

    Sweep.addSentinel(tess, smin, smax, tmin);
    Sweep.addSentinel(tess, smin, smax, tmax);
  }

  static public function doneEdgeDict(tess:Tesselator):Void
  {
    var reg;
    var fixedEdges = 0;

    while ((reg = tess.dict.min().key) != null) {
      /*
      * At the end of all processing, the dictionary should contain
      * only the two sentinel edges, plus at most one "fixable" edge
      * created by ConnectRightVertex().
      */
      if (!reg.sentinel) {
        Debug.assert(reg.fixUpperEdge);
        Debug.assert((++fixedEdges) == 1);
      }
      Debug.assert(reg.windingNumber == 0);
      Sweep.deleteRegion(tess, reg);
      /*    tessMeshDelete( reg->eUp );*/
    }
  //	dictDeleteDict( &tess->alloc, tess->dict );
  }
  
  static public function removeDegenerateEdges(tess:Tesselator):Void {
    /*
    * Remove zero-length edges, and contours with fewer than 3 vertices.
    */
    var e, eNext, eLnext;
    var eHead = tess.mesh.eHead;

    /*LINTED*/
    e = eHead.next;
    while (e != eHead) {
      eNext = e.next;
      eLnext = e.Lnext;

      if (Geom.vertEq(e.Org, e.Dst) && e.Lnext.Lnext != e) {
        /* Zero-length edge, contour has at least 3 edges */
        Sweep.spliceMergeVertices(tess, eLnext, e);	/* deletes e->Org */
        tess.mesh.delete(e); /* e is a self-loop */
        e = eLnext;
        eLnext = e.Lnext;
      }
      if (eLnext.Lnext == e) {
        /* Degenerate contour (one or two edges) */
        if (eLnext != e) {
          if (eLnext == eNext || eLnext == eNext.Sym) { eNext = eNext.next; }
          tess.mesh.delete(eLnext);
        }
        if (e == eNext || e == eNext.Sym) { eNext = eNext.next; }
        tess.mesh.delete(e);
      }
      e = eNext;
    }
  }

  static public function initPriorityQ(tess):Bool {
    /*
    * Insert all vertices into the priority queue which determines the
    * order in which vertices cross the sweep line.
    */
    var pq:PriorityQ;
    var v, vHead:TessVertex;
    var vertexCount = 0;
    
    vHead = tess.mesh.vHead;
    v = vHead.next;
    while (v != vHead) {
      vertexCount++;
      v = v.next;
    }
    /* Make sure there is enough space for sentinels. */
    vertexCount += 8; //MAX( 8, tess->alloc.extraVertices );
    
    pq = tess.pq = new PriorityQ(vertexCount, Geom.vertLeq);
  //	if (pq == NULL) return 0;

    vHead = tess.mesh.vHead;
    v = vHead.next;
    while (v != vHead) {
      v.pqHandle = pq.insert(v);
      v = v.next;
  //		if (v.pqHandle == INV_HANDLE)
  //			break;
    }

    if (v != vHead) {
      return false;
    }

    pq.init();

    return true;
  }

  static public function donePriorityQ(tess):Void {
    tess.pq = null;
  }
  
  static public function removeDegenerateFaces(tess:Tesselator, mesh:TessMesh):Bool {
    /*
    * Delete any degenerate faces with only two edges.  WalkDirtyRegions()
    * will catch almost all of these, but it won't catch degenerate faces
    * produced by splice operations on already-processed edges.
    * The two places this can happen are in FinishLeftRegions(), when
    * we splice in a "temporary" edge produced by ConnectRightVertex(),
    * and in CheckForLeftSplice(), where we splice already-processed
    * edges to ensure that our dictionary invariants are not violated
    * by numerical errors.
    *
    * In both these cases it is *very* dangerous to delete the offending
    * edge at the time, since one of the routines further up the stack
    * will sometimes be keeping a pointer to that edge.
    */
    var f, fNext;
    var e;

    /*LINTED*/
    f = mesh.fHead.next;
    while (f != mesh.fHead) {
      fNext = f.next;
      e = f.anEdge;
      Debug.assert(e.Lnext != e);

      if (e.Lnext.Lnext == e) {
        /* A face with only two edges */
        Sweep.addWinding(e.Onext, e);
        tess.mesh.delete(e);
      }
      f = fNext;
    }
    return true;
  }

  static public function computeInterior(tess:Tesselator):Bool {
    /*
    * tessComputeInterior( tess ) computes the planar arrangement specified
    * by the given contours, and further subdivides this arrangement
    * into regions.  Each region is marked "inside" if it belongs
    * to the polygon, according to the rule given by tess->windingRule.
    * Each interior region is guaranteed be monotone.
    */
    var v, vNext;

    /* Each vertex defines an event for our sweep line.  Start by inserting
    * all the vertices in a priority queue.  Events are processed in
    * lexicographic order, ie.
    *
    *	e1 < e2  iff  e1.x < e2.x || (e1.x == e2.x && e1.y < e2.y)
    */
    Sweep.removeDegenerateEdges(tess);
    if (!Sweep.initPriorityQ(tess)) return false; /* if error */
    Sweep.initEdgeDict(tess);

    var pq = tess.pq;
    
    while ((v = tess.pq.extractMin()) != null) {
      while (true) {
        vNext = tess.pq.min();
        if (vNext == null || !Geom.vertEq(vNext, v)) break;

        /* Merge together all vertices at exactly the same location.
        * This is more efficient than processing them one at a time,
        * simplifies the code (see ConnectLeftDegenerate), and is also
        * important for correct handling of certain degenerate cases.
        * For example, suppose there are two identical edges A and B
        * that belong to different contours (so without this code they would
        * be processed by separate sweep events).  Suppose another edge C
        * crosses A and B from above.  When A is processed, we split it
        * at its intersection point with C.  However this also splits C,
        * so when we insert B we may compute a slightly different
        * intersection point.  This might leave two edges with a small
        * gap between them.  This kind of error is especially obvious
        * when using boundary extraction (TESS_BOUNDARY_ONLY).
        */
        vNext = tess.pq.extractMin();
        Sweep.spliceMergeVertices(tess, v.anEdge, vNext.anEdge);
      }
      Sweep.sweepEvent(tess, v);
    }

    /* Set tess->event for debugging purposes */
    tess.event = tess.dict.min().key.eUp.Org;
    Sweep.debugEvent(tess);
    Sweep.doneEdgeDict(tess);
    Sweep.donePriorityQ(tess);

    if (!Sweep.removeDegenerateFaces(tess, tess.mesh)) return false;
    tess.mesh.check();

    return true;
  }
  

}


/**
 * The actual tesselator class.
 * 
 * For more info about how to use this class see the demo by Mikko Mononen on (https://github.com/memononen/tess2.js).
 * Live version rehosted here (https://dl.dropboxusercontent.com/u/32864004/dev/FPDemo/tess2.js-demo/index.html)
 * 
 * Further reading: http://www.glprogramming.com/red/chapter11.html
 */
@:expose
class Tesselator
{
  /*** state needed for collecting the input data ***/
  public var mesh:TessMesh = null;					/* stores the input contours, and eventually
                            * the tessellation itself */

  /*** state needed for projecting onto the sweep plane ***/

  public var normal:Array<Float> = [0.0, 0.0, 0.0];	/* user-specified normal (if provided) */
  public var sUnit:Array<Float> = [0.0, 0.0, 0.0];	/* unit vector in s-direction (debugging) */
  public var tUnit:Array<Float> = [0.0, 0.0, 0.0];	/* unit vector in t-direction (debugging) */

  public var bmin:Array<Float> = [0.0, 0.0];
  public var bmax:Array<Float> = [0.0, 0.0];

  /*** state needed for the line sweep ***/
  public var windingRule:WindingRule;					/* rule for determining polygon interior */

  public var dict:Dict = null;						/* edge dictionary for sweep line */
  public var pq:PriorityQ = null;						/* priority queue of vertex events */
  public var event:TessVertex = null;					/* current sweep event being processed */

  public var vertexIndexCounter:Int = 0;
  
  public var vertices:Array<Float> = [];
  public var vertexIndices:Array<Int> = [];
  public var vertexCount:Int = 0;
  public var elements:Array<Int> = [];
  public var elementCount:Int = 0;
  
  
  public function new() 
  {
    windingRule = WindingRule.ODD;
  }
  
  private function dot_(u:Array<Float>, v:Array<Float>):Float {
    return (u[0] * v[0] + u[1] * v[1] + u[2] * v[2]);
  }

  private function normalize_(v:Array<Float>):Void {
    var len = v[0] * v[0] + v[1] * v[1] + v[2] * v[2];
    Debug.assert(len > 0.0);
    len = Math.sqrt(len);
    v[0] /= len;
    v[1] /= len;
    v[2] /= len;
  }

  private function longAxis_(v:Array<Float>):Int {
    var i = 0;
    if (Math.abs(v[1]) > Math.abs(v[0])) { i = 1; }
    if (Math.abs(v[2]) > Math.abs(v[i])) { i = 2; }
    return i;
  }

  private function computeNormal_(norm:Array<Float>):Void
  {
    var v, v1, v2;
    var c, tLen2, maxLen2;
    var maxVal = [.0,.0,.0], minVal = [.0,.0,.0], d1 = [.0,.0,.0], d2 = [.0,.0,.0], tNorm = [.0,.0,.0];
    var maxVert = [null,null,null], minVert = [null,null,null];
    var vHead = this.mesh.vHead;
    var i;

    v = vHead.next;
    for (i in 0...3) {
      c = v.coords[i];
      minVal[i] = c;
      minVert[i] = v;
      maxVal[i] = c;
      maxVert[i] = v;
    }

    v = vHead.next;
    while (v != vHead) {
      for (i in 0...3) {
        c = v.coords[i];
        if (c < minVal[i]) { minVal[i] = c; minVert[i] = v; }
        if (c > maxVal[i]) { maxVal[i] = c; maxVert[i] = v; }
      }
      v = v.next;
    }

    /* Find two vertices separated by at least 1/sqrt(3) of the maximum
    * distance between any two vertices
    */
    i = 0;
    if (maxVal[1] - minVal[1] > maxVal[0] - minVal[0]) { i = 1; }
    if (maxVal[2] - minVal[2] > maxVal[i] - minVal[i]) { i = 2; }
    if (minVal[i] >= maxVal[i]) {
      /* All vertices are the same -- normal doesn't matter */
      norm[0] = 0; norm[1] = 0; norm[2] = 1;
      return;
    }

    /* Look for a third vertex which forms the triangle with maximum area
    * (Length of normal == twice the triangle area)
    */
    maxLen2 = .0;
    v1 = minVert[i];
    v2 = maxVert[i];
    d1[0] = v1.coords[0] - v2.coords[0];
    d1[1] = v1.coords[1] - v2.coords[1];
    d1[2] = v1.coords[2] - v2.coords[2];
    v = vHead.next;
    while (v != vHead) {
      d2[0] = v.coords[0] - v2.coords[0];
      d2[1] = v.coords[1] - v2.coords[1];
      d2[2] = v.coords[2] - v2.coords[2];
      tNorm[0] = d1[1]*d2[2] - d1[2]*d2[1];
      tNorm[1] = d1[2]*d2[0] - d1[0]*d2[2];
      tNorm[2] = d1[0]*d2[1] - d1[1]*d2[0];
      tLen2 = tNorm[0]*tNorm[0] + tNorm[1]*tNorm[1] + tNorm[2]*tNorm[2];
      if (tLen2 > maxLen2) {
        maxLen2 = tLen2;
        norm[0] = tNorm[0];
        norm[1] = tNorm[1];
        norm[2] = tNorm[2];
      }
      v = v.next;
    }

    if (maxLen2 <= 0) {
      /* All points lie on a single line -- any decent normal will do */
      norm[0] = norm[1] = norm[2] = 0;
      norm[this.longAxis_(d1)] = 1;
    }
  }
  
  private function checkOrientation_():Void {
    var area;
    var f, fHead = this.mesh.fHead;
    var v, vHead = this.mesh.vHead;
    var e;

    /* When we compute the normal automatically, we choose the orientation
    * so that the the sum of the signed areas of all contours is non-negative.
    */
    area = .0;
    f = fHead.next;
    while (f != fHead) {
      e = f.anEdge;
      if (e.winding <= 0) {
        f = f.next;
        continue;
      }
      do {
        area += (e.Org.s - e.Dst.s) * (e.Org.t + e.Dst.t);
        e = e.Lnext;
      } while (e != f.anEdge);
      f = f.next;
    }
    if (area < 0) {
      /* Reverse the orientation by flipping all the t-coordinates */
      v = vHead.next;
      while (v != vHead) {
        v.t = - v.t;
        v = v.next;
      }
      this.tUnit[0] = -this.tUnit[0];
      this.tUnit[1] = -this.tUnit[1];
      this.tUnit[2] = -this.tUnit[2];
    }
  }

/*	#ifdef FOR_TRITE_TEST_PROGRAM
  #include <stdlib.h>
  extern int RandomSweep;
  #define S_UNIT_X	(RandomSweep ? (2*drand48()-1) : 1.0)
  #define S_UNIT_Y	(RandomSweep ? (2*drand48()-1) : 0.0)
  #else
  #if defined(SLANTED_SWEEP) */
  /* The "feature merging" is not intended to be complete.  There are
  * special cases where edges are nearly parallel to the sweep line
  * which are not implemented.  The algorithm should still behave
  * robustly (ie. produce a reasonable tesselation) in the presence
  * of such edges, however it may miss features which could have been
  * merged.  We could minimize this effect by choosing the sweep line
  * direction to be something unusual (ie. not parallel to one of the
  * coordinate axes).
  */
/*	#define S_UNIT_X	(TESSreal)0.50941539564955385	// Pre-normalized
  #define S_UNIT_Y	(TESSreal)0.86052074622010633
  #else
  #define S_UNIT_X	(TESSreal)1.0
  #define S_UNIT_Y	(TESSreal)0.0
  #endif
  #endif*/

  /* Determine the polygon normal and project vertices onto the plane
  * of the polygon.
  */
  private function projectPolygon_():Void {
    var v, vHead = this.mesh.vHead;
    var norm = [.0,.0,.0];
    var sUnit, tUnit;
    var i, first, computedNormal = false;

    norm[0] = this.normal[0];
    norm[1] = this.normal[1];
    norm[2] = this.normal[2];
    if (norm[0] == 0.0 && norm[1] == 0.0 && norm[2] == 0.0 ) {
      this.computeNormal_(norm);
      computedNormal = true;
    }
    sUnit = this.sUnit;
    tUnit = this.tUnit;
    i = this.longAxis_(norm);

/*	#if defined(FOR_TRITE_TEST_PROGRAM) || defined(TRUE_PROJECT)
    // Choose the initial sUnit vector to be approximately perpendicular
    // to the normal.
    
    Normalize( norm );

    sUnit[i] = 0;
    sUnit[(i+1)%3] = S_UNIT_X;
    sUnit[(i+2)%3] = S_UNIT_Y;

    // Now make it exactly perpendicular 
    w = Dot( sUnit, norm );
    sUnit[0] -= w * norm[0];
    sUnit[1] -= w * norm[1];
    sUnit[2] -= w * norm[2];
    Normalize( sUnit );

    // Choose tUnit so that (sUnit,tUnit,norm) form a right-handed frame 
    tUnit[0] = norm[1]*sUnit[2] - norm[2]*sUnit[1];
    tUnit[1] = norm[2]*sUnit[0] - norm[0]*sUnit[2];
    tUnit[2] = norm[0]*sUnit[1] - norm[1]*sUnit[0];
    Normalize( tUnit );
  #else*/
    /* Project perpendicular to a coordinate axis -- better numerically */
    sUnit[i] = 0;
    sUnit[(i + 1) % 3] = 1.0;
    sUnit[(i + 2) % 3] = 0.0;

    tUnit[i] = 0;
    tUnit[(i + 1) % 3] = 0.0;
    tUnit[(i + 2) % 3] = (norm[i] > 0) ? 1.0 : -1.0;
//	#endif

    /* Project the vertices onto the sweep plane */
    v = vHead.next;
    while (v != vHead) {
      v.s = this.dot_(v.coords, sUnit);
      v.t = this.dot_(v.coords, tUnit);
      v = v.next;
    }
    if (computedNormal) {
      this.checkOrientation_();
    }

    /* Compute ST bounds. */
    first = true;
    v = vHead.next;
    while (v != vHead) {
      if (first) {
        this.bmin[0] = this.bmax[0] = v.s;
        this.bmin[1] = this.bmax[1] = v.t;
        first = false;
      } else {
        if (v.s < this.bmin[0]) this.bmin[0] = v.s;
        if (v.s > this.bmax[0]) this.bmax[0] = v.s;
        if (v.t < this.bmin[1]) this.bmin[1] = v.t;
        if (v.t > this.bmax[1]) this.bmax[1] = v.t;
      }
      v = v.next;
    }
  }

  private function addWinding_(eDst:TessHalfEdge, eSrc:TessHalfEdge):Void {
    eDst.winding += eSrc.winding;
    eDst.Sym.winding += eSrc.Sym.winding;
  }
  
    /* tessMeshTessellateMonoRegion( face ) tessellates a monotone region
    * (what else would it do??)  The region must consist of a single
    * loop of half-edges (see mesh.h) oriented CCW.  "Monotone" in this
    * case means that any vertical line intersects the interior of the
    * region in a single interval.  
    *
    * Tessellation consists of adding interior edges (actually pairs of
    * half-edges), to split the region into non-overlapping triangles.
    *
    * The basic idea is explained in Preparata and Shamos (which I don''t
    * have handy right now), although their implementation is more
    * complicated than this one.  The are two edge chains, an upper chain
    * and a lower chain.  We process all vertices from both chains in order,
    * from right to left.
    *
    * The algorithm ensures that the following invariant holds after each
    * vertex is processed: the untessellated region consists of two
    * chains, where one chain (say the upper) is a single edge, and
    * the other chain is concave.  The left vertex of the single edge
    * is always to the left of all vertices in the concave chain.
    *
    * Each step consists of adding the rightmost unprocessed vertex to one
    * of the two chains, and forming a fan of triangles from the rightmost
    * of two chain endpoints.  Determining whether we can add each triangle
    * to the fan is a simple orientation test.  By making the fan as large
    * as possible, we restore the invariant (check it yourself).
    */
  //	int tessMeshTessellateMonoRegion( TESSmesh *mesh, TESSface *face )
  private function tessellateMonoRegion_(mesh:TessMesh, face:TessFace):Bool {
    var up, lo;

    /* All edges are oriented CCW around the boundary of the region.
    * First, find the half-edge whose origin vertex is rightmost.
    * Since the sweep goes from left to right, face->anEdge should
    * be close to the edge we want.
    */
    up = face.anEdge;
    Debug.assert(up.Lnext != up && up.Lnext.Lnext != up);

    while (Geom.vertLeq(up.Dst, up.Org)) up = up.Lprev;
    while (Geom.vertLeq(up.Org, up.Dst)) up = up.Lnext;
    
    lo = up.Lprev;

    while (up.Lnext != lo) {
      if (Geom.vertLeq(up.Dst, lo.Org)) {
        /* up->Dst is on the left.  It is safe to form triangles from lo->Org.
        * The EdgeGoesLeft test guarantees progress even when some triangles
        * are CW, given that the upper and lower chains are truly monotone.
        */
        while (lo.Lnext != up && (Geom.edgeGoesLeft(lo.Lnext)
             || Geom.edgeSign(lo.Org, lo.Dst, lo.Lnext.Dst) <= 0.0 )) 
        {
          var tempHalfEdge = mesh.connect(lo.Lnext, lo);
          //if (tempHalfEdge == NULL) return 0;
          lo = tempHalfEdge.Sym;
        }
        lo = lo.Lprev;
      } else {
        /* lo->Org is on the left.  We can make CCW triangles from up->Dst. */
        while (lo.Lnext != up && (Geom.edgeGoesRight(up.Lprev)
             || Geom.edgeSign(up.Dst, up.Org, up.Lprev.Org) >= 0.0 )) 
        {
          var tempHalfEdge = mesh.connect(up, up.Lprev);
          //if (tempHalfEdge == NULL) return 0;
          up = tempHalfEdge.Sym;
        }
        up = up.Lnext;
      }
    }

    /* Now lo->Org == up->Dst == the leftmost vertex.  The remaining region
    * can be tessellated in a fan from this leftmost vertex.
    */
    Debug.assert(lo.Lnext != up);
    while (lo.Lnext.Lnext != up) {
      var tempHalfEdge = mesh.connect(lo.Lnext, lo);
      //if (tempHalfEdge == NULL) return 0;
      lo = tempHalfEdge.Sym;
    }

    return true;
  }

  /* tessMeshTessellateInterior( mesh ) tessellates each region of
  * the mesh which is marked "inside" the polygon.  Each such region
  * must be monotone.
  */
  //int tessMeshTessellateInterior( TESSmesh *mesh )
  private function tessellateInterior_(mesh:TessMesh):Bool {
    var f, next;

    /*LINTED*/
    f = mesh.fHead.next;
    while (f != mesh.fHead) {
      /* Make sure we don''t try to tessellate the new triangles. */
      next = f.next;
      if (f.inside) {
        if (!this.tessellateMonoRegion_(mesh, f)) return false;
      }
      f = next;
    }

    return true;
  }

  /*
    Starting with a valid triangulation, uses the Edge Flip algorithm to
    refine the triangulation into a Constrained Delaunay Triangulation.
  */
  //int tessMeshRefineDelaunay( TESSmesh *mesh, TESSalloc *alloc )
  //NOTE: double check this function (in regards to allocator esp.)
  private function refineDelaunay_(mesh:TessMesh):Void
  {
    /* At this point, we have a valid, but not optimal, triangulation.
       We refine the triangulation using the Edge Flip algorithm */

  /*
     1) Find all internal edges
     2) Mark all dual edges
     3) insert all dual edges into a queue
  */
    var f:TessFace;
    var stack = [];
    var e:TessHalfEdge;
    var edges:Array<TessHalfEdge> = [null, null, null, null];
    
    f = mesh.fHead.next;
    while (f != mesh.fHead) {
      if (f.inside) {
        e = f.anEdge;
        do {
          e.mark = Geom.edgeIsInternal(e); /* Mark internal edges */
          if (e.mark && !e.Sym.mark) stack.push(e); /* Insert into queue */
          e = e.Lnext;
        } while (e != f.anEdge);
      }
      f = f.next;
    }
    
    // Pop stack until we find a reversed edge
    // Flip the reversed edge, and insert any of the four opposite edges
    // which are internal and not already in the stack (!marked)
    while (stack.length > 0) {
      e = stack.pop();
      e.mark = e.Sym.mark = false;
      if (!Geom.edgeIsLocallyDelaunay(e)) {
        TessMesh.flipEdge(mesh, e);
        // for each opposite edge
        edges[0] = e.Lnext;
        edges[1] = e.Lprev;
        edges[2] = e.Sym.Lnext;
        edges[3] = e.Sym.Lprev;
        //NOTE: check upper bound
        for (i in 0...3) {
          if (!edges[i].mark && Geom.edgeIsInternal(edges[i])) {
            edges[i].mark = edges[i].Sym.mark = true;
            stack.push(edges[i]);
          }
        }
      }
    }
    
    for (e in stack) stack.pop();
    stack = null;
  }

  /* tessMeshDiscardExterior( mesh ) zaps (ie. sets to NULL) all faces
  * which are not marked "inside" the polygon.  Since further mesh operations
  * on NULL faces are not allowed, the main purpose is to clean up the
  * mesh so that exterior loops are not represented in the data structure.
  */
  //void tessMeshDiscardExterior( TESSmesh *mesh )
  private function discardExterior_(mesh:TessMesh):Void {
    var f, next;

    /*LINTED*/
    f = mesh.fHead.next;
    while (f != mesh.fHead) {
      /* Since f will be destroyed, save its next pointer. */
      next = f.next;
      if (!f.inside) {
        mesh.zapFace(f);
      }
      f = next;
    }
  }

  /* tessMeshSetWindingNumber( mesh, value, keepOnlyBoundary ) resets the
  * winding numbers on all edges so that regions marked "inside" the
  * polygon have a winding number of "value", and regions outside
  * have a winding number of 0.
  *
  * If keepOnlyBoundary is TRUE, it also deletes all edges which do not
  * separate an interior region from an exterior one.
  */
//	int tessMeshSetWindingNumber( TESSmesh *mesh, int value, int keepOnlyBoundary )
  private function setWindingNumber_(mesh:TessMesh, value:Int, keepOnlyBoundary:Bool):Void {
    var e, eNext;

    e = mesh.eHead.next;
    while (e != mesh.eHead) {
      eNext = e.next;
      if (e.Rface.inside != e.Lface.inside) {

        /* This is a boundary edge (one side is interior, one is exterior). */
        e.winding = (e.Lface.inside) ? value : -value;
      } else {

        /* Both regions are interior, or both are exterior. */
        if (!keepOnlyBoundary) {
          e.winding = 0;
        } else {
          mesh.delete(e);
        }
      }
      e = eNext;
    }
  }

  private function getNeighbourFace_(edge:TessHalfEdge):Int
  {
    if (edge.Rface == null)
      return -1;
    if (!edge.Rface.inside)
      return -1;
    return edge.Rface.n;
  }

  private function outputPolymesh_(mesh:TessMesh, resultsType:ResultType, polySize:Int, vertexDim:Int):Void {
    var v;
    var f;
    var edge;
    var maxFaceCount = 0;
    var maxVertexCount = 0;
    var faceVerts, i;
    var elements = 0;
    var vert;

    // Assume that the input data is triangles now.
    // Try to merge as many polygons as possible
    if (polySize > 3)
    {
      mesh.mergeConvexFaces(polySize);
    }

    // Mark unused
    v = mesh.vHead.next;
    while (v != mesh.vHead) {
      v.n = -1;
      v = v.next;
    }

    // Create unique IDs for all vertices and faces.
    f = mesh.fHead.next;
    while (f != mesh.fHead)
    {
      f.n = -1;
      if (!f.inside) {
        f = f.next;
        continue;
      }

      edge = f.anEdge;
      faceVerts = 0;
      do
      {
        v = edge.Org;
        if (v.n == -1)
        {
          v.n = maxVertexCount;
          maxVertexCount++;
        }
        faceVerts++;
        edge = edge.Lnext;
      }
      while (edge != f.anEdge);
      
      Debug.assert(faceVerts <= polySize);

      f.n = maxFaceCount;
      ++maxFaceCount;
      f = f.next;
    }

    this.elementCount = maxFaceCount;
    if (resultsType == ResultType.CONNECTED_POLYGONS)
      maxFaceCount *= 2;
/*		tess.elements = (TESSindex*)tess->alloc.memalloc( tess->alloc.userData,
                              sizeof(TESSindex) * maxFaceCount * polySize );
    if (!tess->elements)
    {
      tess->outOfMemory = 1;
      return;
    }*/
    this.elements = [];
    //this.elements.length = maxFaceCount * polySize;
    
    this.vertexCount = maxVertexCount;
/*		tess->vertices = (TESSreal*)tess->alloc.memalloc( tess->alloc.userData,
                             sizeof(TESSreal) * tess->vertexCount * vertexSize );
    if (!tess->vertices)
    {
      tess->outOfMemory = 1;
      return;
    }*/
    this.vertices = [];
    //this.vertices.length = maxVertexCount * vertexSize;

/*		tess->vertexIndices = (TESSindex*)tess->alloc.memalloc( tess->alloc.userData,
                                sizeof(TESSindex) * tess->vertexCount );
    if (!tess->vertexIndices)
    {
      tess->outOfMemory = 1;
      return;
    }*/
    this.vertexIndices = [];
    //this.vertexIndices.length = maxVertexCount;

    
    // Output vertices.
    v = mesh.vHead.next;
    while (v != mesh.vHead)
    {
      if (v.n != -1)
      {
        // Store coordinate
        var idx = v.n * vertexDim;
        this.vertices[idx + 0] = v.coords[0];
        this.vertices[idx + 1] = v.coords[1];
        if (vertexDim > 2)
          this.vertices[idx + 2] = v.coords[2];
        // Store vertex index.
        this.vertexIndices[v.n] = v.idx;
      }
      v = v.next;
    }

    // Output indices.
    var nel = 0;
    f = mesh.fHead.next;
    while (f != mesh.fHead) 
    {
      if (!f.inside) {
        f = f.next;
        continue;
      }
      
      // Store polygon
      edge = f.anEdge;
      faceVerts = 0;
      do
      {
        v = edge.Org;
        this.elements[nel++] = v.n;
        faceVerts++;
        edge = edge.Lnext;
      }
      while (edge != f.anEdge);
      // Fill unused.
      for (i in faceVerts...polySize)
        this.elements[nel++] = -1;

      // Store polygon connectivity
      if (resultsType == ResultType.CONNECTED_POLYGONS)
      {
        edge = f.anEdge;
        do
        {
          this.elements[nel++] = this.getNeighbourFace_(edge);
          edge = edge.Lnext;
        }
        while (edge != f.anEdge);
        // Fill unused.
        for (i in faceVerts...polySize)
          this.elements[nel++] = -1;
      }
      f = f.next;
    }
  }
  
  //	void OutputContours( TESStesselator *tess, TESSmesh *mesh, int vertexSize )
  private function outputContours_(mesh:TessMesh, vertexDim:Int):Void {
    var f;
    var edge;
    var start;
    var verts;
    var elements;
    var vertInds;
    var startVert = 0;
    var vertCount = 0;

    this.vertexCount = 0;
    this.elementCount = 0;

    f = mesh.fHead.next;
    while (f != mesh.fHead)
    {
      if (!f.inside) {
        f = f.next;
        continue;
      }

      start = edge = f.anEdge;
      do
      {
        this.vertexCount++;
        edge = edge.Lnext;
      } while (edge != start);

      this.elementCount++;
      f = f.next;
    }

/*		tess->elements = (TESSindex*)tess->alloc.memalloc( tess->alloc.userData,
                              sizeof(TESSindex) * tess->elementCount * 2 );
    if (!tess->elements)
    {
      tess->outOfMemory = 1;
      return;
    }*/
    this.elements = [];
    //this.elements.length = this.elementCount * 2;
    
/*		tess->vertices = (TESSreal*)tess->alloc.memalloc( tess->alloc.userData,
                              sizeof(TESSreal) * tess->vertexCount * vertexSize );
    if (!tess->vertices)
    {
      tess->outOfMemory = 1;
      return;
    }*/
    this.vertices = [];
    //this.vertices.length = this.vertexCount * vertexSize;

/*		tess->vertexIndices = (TESSindex*)tess->alloc.memalloc( tess->alloc.userData,
                                sizeof(TESSindex) * tess->vertexCount );
    if (!tess->vertexIndices)
    {
      tess->outOfMemory = 1;
      return;
    }*/
    this.vertexIndices = [];
    //this.vertexIndices.length = this.vertexCount;

    var nv = 0;
    var nvi = 0;
    var nel = 0;
    startVert = 0;

    f = mesh.fHead.next;
    while (f != mesh.fHead)
    {
      if (!f.inside) {
        f = f.next;
        continue;
      }

      vertCount = 0;
      start = edge = f.anEdge;
      do
      {
        this.vertices[nv++] = edge.Org.coords[0];
        this.vertices[nv++] = edge.Org.coords[1];
        if (vertexDim > 2)
          this.vertices[nv++] = edge.Org.coords[2];
        this.vertexIndices[nvi++] = edge.Org.idx;
        vertCount++;
        edge = edge.Lnext;
      } while (edge != start);

      this.elements[nel++] = startVert;
      this.elements[nel++] = vertCount;

      startVert += vertCount;
      f = f.next;
    }
  }

  public function addContour(vertexDim:Int, vertices:Array<Float>):Void
  {
    var e;
    var i;

    if (this.mesh == null)
      this.mesh = new TessMesh();
/*	 	if ( tess->mesh == NULL ) {
      tess->outOfMemory = 1;
      return;
    }*/

    if (vertexDim < 2)
      vertexDim = 2;
    if (vertexDim > 3)
      vertexDim = 3;

    e = null;
    i = 0;
    while (i < vertices.length)
    {
      if (e == null) {
        /* Make a self-loop (one vertex, one edge). */
        e = this.mesh.makeEdge();
/*				if ( e == NULL ) {
          tess->outOfMemory = 1;
          return;
        }*/
        this.mesh.splice(e, e.Sym);
      } else {
        /* Create a new vertex and edge which immediately follow e
        * in the ordering around the left face.
        */
        this.mesh.splitEdge(e);
        e = e.Lnext;
      }

      /* The new vertex is now e->Org. */
      e.Org.coords[0] = vertices[i + 0];
      e.Org.coords[1] = vertices[i + 1];
      if (vertexDim > 2)
        e.Org.coords[2] = vertices[i + 2];
      else
        e.Org.coords[2] = 0.0;
      /* Store the insertion number so that the vertex can be later recognized. */
      e.Org.idx = this.vertexIndexCounter++;

      /* The winding of an edge says how the winding number changes as we
      * cross from the edge''s right face to its left face.  We add the
      * vertices in such an order that a CCW contour will add +1 to
      * the winding number of the region inside the contour.
      */
      e.winding = 1;
      e.Sym.winding = -1;
      i += vertexDim;
    }
  }

  // int tessTesselate( TESStesselator *tess, int windingRule, int elementType, int polySize, int vertexSize, const TESSreal* normal )
  public function tesselate(windingRule:WindingRule, resultType:ResultType, polySize:Int, vertexDim:Int, normal:Array<Float> = null):Bool {
    this.vertices = [];
    this.elements = [];
    this.vertexIndices = [];

    this.vertexIndexCounter = 0;
    
    if (normal != null)
    {
      this.normal[0] = normal[0];
      this.normal[1] = normal[1];
      this.normal[2] = normal[2];
    }

    this.windingRule = windingRule;

    if (vertexDim < 2)
      vertexDim = 2;
    if (vertexDim > 3)
      vertexDim = 3;

/*		if (setjmp(tess->env) != 0) { 
      // come back here if out of memory
      return 0;
    }*/

    if (this.mesh == null)
    {
      return false;
    }

    /* Determine the polygon normal and project vertices onto the plane
    * of the polygon.
    */
    this.projectPolygon_();

    /* tessComputeInterior( tess ) computes the planar arrangement specified
    * by the given contours, and further subdivides this arrangement
    * into regions.  Each region is marked "inside" if it belongs
    * to the polygon, according to the rule given by tess->windingRule.
    * Each interior region is guaranteed be monotone.
    */
    Sweep.computeInterior(this);

    var mesh = this.mesh;

    /* If the user wants only the boundary contours, we throw away all edges
    * except those which separate the interior from the exterior.
    * Otherwise we tessellate all the regions marked "inside".
    */
    if (resultType == ResultType.BOUNDARY_CONTOURS) {
      this.setWindingNumber_(mesh, 1, true);
    } else {
      this.tessellateInterior_(mesh); 
      if (resultType == ResultType.EXPERIMENTAL_DELAUNAY) {
        this.refineDelaunay_(mesh);
        //resultType = ResultType.POLYGONS; //NOTE: check this overridden var
        polySize = 3;
      }
    }
//		if (rc == 0) longjmp(tess->env,1);  /* could've used a label */

    mesh.check();

    if (resultType == ResultType.BOUNDARY_CONTOURS) {
      this.outputContours_(mesh, vertexDim);     /* output contours */
    }
    else
    {
      this.outputPolymesh_(mesh, resultType, polySize, vertexDim);     /* output polygons */
    }

//			tess.mesh = null;

    return true;
  }
}