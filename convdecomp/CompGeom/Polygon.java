package CompGeom;

public class Polygon extends PointList {
  public Polygon(int n) { super(n); }
  public Polygon(PointList pl) { super(pl); }

  public void draw(java.awt.Graphics g, boolean label) {
    super.draw(g, label);
    drawPolygon(g, number());
  }
}
