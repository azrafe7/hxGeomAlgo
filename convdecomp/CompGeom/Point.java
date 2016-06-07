package CompGeom;

import java.awt.Graphics;

public class Point extends Object {
  protected double x, y;
  
  public Point(double px, double py) {x = px; y = py;}
  public Point(int px, int py) {x = px; y = -py;}
  public Point(Point p) {this(p.x, p.y);}
  public Point(java.awt.Point p) {this(p.x, p.y);}
  public Point(Homog p) {this(p.x/p.w, p.y/p.w);}

  final protected int x() { return (int) x; } /* drawing needs these */
  final protected int y() { return (int) -y; }

  public Point add(Point p) {x += p.x; y += p.y; return this;}
  public Point sub(Point p) {x -= p.x; y -= p.y; return this;}
  public Point neg() {x = -x; y = -y; return this;}
  public Point mul(double m) {x *= m; y *= m; return this;}
  public Point div(double m) {x /= m; y /= m; return this;}
  final public double len2() {return x*x + y*y;}
  final public double len() {
    if (stats) sqrts++; return Math.sqrt(len2());}
  final public double dist2(Point p) {
    double dx = x - p.x, dy = y - p.y; 
    return dx*dx + dy*dy;
  }
  final public double dist(Point p) {
    if (stats) sqrts++; return Math.sqrt(dist2(p)); }
  public Point normalize() {return div(len());}
  static public Point add(Point p, Point q) {
    return new Point(p.x + q.x, p.y + q.y);
  }
  static public Point sub(Point p, Point q) { 
    return new Point(p.x - q.x, p.y - q.y);
  }
  static public Point lincomb(Point p, double beta, Point q) {
    return new Point(p.x + beta * q.x, p.y + beta * q.y);
  }
  static public Point lincomb(double alpha, Point p, double beta, Point q) {
    return new Point(alpha * p.x + beta * q.x, alpha * p.y + beta * q.y);
  }
  public Point perp() { double tmp = -y; y = x; x = tmp; return this;}
  public double dot(Point p) { return x*p.x + y*p.y;}
  public double perpdot(Point p) { return x*p.y - y*p.x;}
  public double dotperp(Point p) { return - x*p.y + y*p.x;}

/** operate on vector from p to q */
  public double dot(Point p, Point q) { return x*(q.x-p.x) + y*(q.y-p.y); }
  public double perpdot(Point p, Point q) { return x*(q.y-p.y) - y*(q.x-p.x);}
  public double dotperp(Point p, Point q) { return y*(q.x-p.x) - x*(q.y-p.y);}

  public Homog meet(Point p) {
    return new Homog(x*p.y - y*p.x, y - p.y, p.x - x);
  }

  public boolean equals(Point q) {return (x == q.x) && (y == q.y);}
  public boolean less(Point q) { /* true if p.x < q.x, break ties on y */
    double diff = x - q.x;
    if (stats) comparisons++;
    return (diff < 0) || ((diff == 0) && (y < q.y));
  }
  public boolean greater(Point q) { /* true if p.y < q.y */
    double diff = x - q.x;
    if (stats) comparisons++;
    return (diff > 0) || ((diff == 0) && (y > q.y));
  }
  public boolean y_less(Point q) { /* true if p.y < q.y, break ties on x */
    double diff = y - q.y;
    if (stats) comparisons++;
    return (diff < 0) || ((diff == 0) && (x < q.x));
  }

  final static public 
    boolean segmentIntersect(Point a, Point b, Point c, Point d) {
      double abc = det3(a,b,c);
      double abd = det3(a,b,d);
      if (abc*abd > 0) return false;
      if (ON(abc) && ON(abd)) /* all four collinear! */
        return (dot(c, a, b) <= 0.0) || (dot(d, a, b) <= 0.0) || (dot(a, c, d) <= 0.0);
      return det3(c,d,a)*det3(c,d,b) <= 0;
    }

  final static private double det3(Point p, Point q, Point r) {
    if (stats) sidednesstests++;
    return (q.x - p.x)*(r.y - p.y) - (q.y - p.y)*(r.x - p.x);
  }
  final static private boolean LEFT(double test) { return test > 0.0; }
  final static private boolean ON(double test) { return test == 0.0; }
  final static private boolean RIGHT(double test) { return test < 0.0; }

  final static private double dot(Point o, Point p, Point q) {
    if (stats) onlinetests++;
    return (p.x - o.x)*(q.x - o.x) + (p.y - o.y)*(q.y - o.y);
  }
    
  final static public boolean leftORinside(Point p, Point q, Point r) {
    double test = det3(p, q, r);
    return (LEFT(test) || (ON(test) && dot(r, p, q) < 0.0));
  }
  final static public boolean leftORonseg(Point p, Point q, Point r) {
    double test = det3(p, q, r);
    return (LEFT(test) || (ON(test) && dot(r, p, q) <= 0.0));
  }
  final static public boolean right(Point p, Point q, Point r) { 
    return RIGHT(det3(p, q, r));
  }
  final static public boolean left(Point p, Point q, Point r) {
    return LEFT(det3(p, q, r));
  }
  final static public boolean colinear(Point p, Point q, Point r) {
    return ON(det3(p, q, r));
  }

  private final static boolean stats = true;
  private static long elapsed, comparisons, sidednesstests,
                      onlinetests, sqrts; 
  private static long starttime;

  public static String stats() {
    long elapsed = System.currentTimeMillis() - starttime;
    return "\nElapsed Time (ms)"+ Long.toString(elapsed)
         + "\n     Comparisons "+ comparisons
         + "\n Sidedness Tests "+ sidednesstests
	 + "\n    Online Tests "+ onlinetests
	 + "\n    Square roots "+ sqrts;
  }
  public static void reset() { 
    comparisons = sidednesstests = onlinetests = sqrts = 0; 
    starttime = System.currentTimeMillis();
  }

  public String toString() { 
    return " (" + x + ", " + y + ")  ";
  }

  public java.awt.Point toJavaPoint(java.awt.Point p) { 
    p.x = x(); p.y = y(); return p; 
  }

  final public void drawVector(Graphics g, Point orig) {
    orig.drawDot(g); 
    g.drawLine(orig.x(), orig.y(), orig.x()+x(), orig.y()+y());
  }

  final public void drawCirc(Graphics g, int rad) {
    g.drawOval(x()-rad, y()-rad, rad*2, rad*2);     
  }
  final public void drawDot(Graphics g, int rad) {
    g.fillOval(x()-rad, y()-rad, rad*2, rad*2);     
  }
  final public void drawSquare(Graphics g, int rad) {
    g.fillRect(x()-rad, y()-rad, rad*2, rad*2);     
  }
  final public void drawBox(Graphics g, int rad) {
    g.drawRect(x()-rad, y()-rad, rad*2, rad*2);     
  }

  final private static int RADIUS = 2;
  final public void drawCirc(Graphics g) { drawCirc(g, RADIUS); }
  final public void drawDot(Graphics g) { drawDot(g, RADIUS); }
  final public void drawSquare(Graphics g) { drawSquare(g, RADIUS); }
  final public void drawBox(Graphics g) { drawBox(g, RADIUS); }

  final public void draw(Graphics g) { drawCirc(g, RADIUS); }
  final public void draw(Graphics g, boolean label) {
    draw(g);
    if (label) g.drawString(toString(), x(), y());
  }
}

