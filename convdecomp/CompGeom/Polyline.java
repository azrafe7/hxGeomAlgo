package CompGeom;

public class Polyline extends PointList {
  public Polyline(int n) { super(n); }
  public Polyline(PointList pl) { super(pl); }

  public void draw(java.awt.Graphics g, boolean label) {
    super.draw(g, label);
    drawPolyline(g, number());
  }
}

