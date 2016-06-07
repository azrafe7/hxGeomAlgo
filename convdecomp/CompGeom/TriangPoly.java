package CompGeom;

import java.awt.Graphics;

public class TriangPoly extends Anim2D {
  private PointList sp;
  private int ind[][];
  private double wt[][];

  public final static double INFINITY = 1.0e30;
  public final static int NONE = 0;

  public TriangPoly(PointList pl) { 
    sp = pl;
    wt = new double[sp.number()][sp.number()];
    ind = new int[sp.number()][sp.number()];
    wt = new double[sp.number()][sp.number()];
  }

  public void setTriangle(int i, int j, int k) { /** i<j<k */
    ind[i][k] = j;
    if (animating() && (j != NONE)) {
//      animGraphics.drawLine(sp.p(i).x(), sp.p(i).y(), sp.p(j).x(), sp.p(j).y());
//      animGraphics.drawLine(sp.p(j).x(), sp.p(j).y(), sp.p(k).x(), sp.p(k).y());
      animGraphics.drawLine(sp.p(i).x(), sp.p(i).y(), sp.p(k).x(), sp.p(k).y());
    }
  } 

  public void drawSegs(int i, int j, int ii, int jj) {
    if (animating()) {
      animGraphics.drawLine(sp.p(i).x(), sp.p(i).y(), 
			    sp.p(j).x(), sp.p(j).y());
      animGraphics.drawLine(sp.p(ii).x(), sp.p(ii).y(), 
			    sp.p(jj).x(), sp.p(jj).y());
    }
  }
  public void setWeight(int i, int l, double w) { wt[i][l] = w;}
  public double weight(int i, int l) { return wt[i][l];}

  private void drawhelper(Graphics g, boolean label, int i, int j) {
    if (label) g.drawString(Double.toString(wt[i][j-i]), 
		    (sp.p(i).x()+sp.p(j).x())/2, (sp.p(i).y()+sp.p(j).y())/2);
    g.drawLine(sp.p(i).x(), sp.p(i).y(), sp.p(j).x(), sp.p(j).y());
    if (ind[i][j] != NONE) {
      drawhelper(g, label, i, ind[i][j]);
      drawhelper(g, label, ind[i][j], j);
    }
  }

  public void draw(Graphics g, boolean label) {
//    sp.draw(g, label);
    if (ind[0][sp.number()-1] != NONE) 
      drawhelper(g,label, 0, sp.number()-1);
  }
}
