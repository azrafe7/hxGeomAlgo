import CompGeom.*;

/** Implements the dynamic programming algorithm for minimum weight 
    triangulation of a simple polygon. */
public class MWT extends PointIOApplet {

  public static void main(String args[]) {
    makeStandalone("MWT of simple polygon", new MWT(), 450, 350); 
  }


/** Assumes that the point list contains at least three points */
  public Anim2D compute(PointList pl) {
    TriangPoly tp = new TriangPoly(pl);
    animate(tp);

    for (int l = 2; l < pl.number(); l++) 
      for (int i = 0; i < pl.number()-l; i++) {
	int last = tp.NONE;
	double w = tp.INFINITY;
	for (int j = 1; j < l; j++) {
	  // 	  System.out.println("i"+i+" L"+l+" j"+j+" w"+w+" t"+tp.weight(i, j) + tp.weight(i+j, l-j));
	  if ((w > tp.weight(i, j) + tp.weight(i+j, l-j))
	      && Point.left(pl.p(i), pl.p(i+j), pl.p(i+l))) { 
	    w = tp.weight(i, j) + tp.weight(i+j, l-j); 
	    last = i+j; 
	  }
	}
	tp.setWeight(i,l,w + pl.p(i).dist(pl.p(i+l))); 
	tp.setTriangle(i, last, i+l); 
      }
    return tp;
  }
}
