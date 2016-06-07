package CompGeom;

import java.awt.Graphics;

public final class Homog extends Object {
  protected double w, x, y;
  
  public Homog(double pw, double px, double py) {w = pw; x = px; y = py;}
  public Homog(Point p) {this(1.0, p.x, p.y);}
  public Homog(int px, int py) {this(1.0, px, -py);}
  public Homog(java.awt.Point p) {this(p.x, p.y);}

  public final static Homog INFINITY = new Homog(1.0, 0.0, 0.0);

  public Homog assign(double pw, double px, double py) {
      w = pw; x = px; y = py; return this;
  }
  final protected int x() { return (int) (x/w); } // drawing needs these
  final protected int y() { return (int) (-y/w); } 

  public Homog add(Homog p) {x += p.x; y += p.y; return this;}
  public Homog sub(Homog p) {x -= p.x; y -= p.y; return this;}
  public Homog neg() {w = -w; x = -x; y = -y; return this;}
  public Homog mul(double m) {w *= m; x *= m; y *= m; return this;}
  public Homog div(double m) {w /= m; x /= m; y /= m; return this;}
  public Homog normalize() {return div(len());}
  public double len2() {return x*x + y*y;}
  public double len() {return Math.sqrt(this.len2());}

  final public Homog perp() {double tmp = -y; y = x; x = tmp; return this;}
  public double dot(Point p) {return w + x*p.x + y*p.y;}
  public double dot(Homog p) {return w*p.w + x*p.x + y*p.y;}
  public double perpdot(Homog p) {return x*p.y - y*p.x;}
  public double dotperp(Homog p) {return - x*p.y + y*p.x;}
  public boolean equals(Homog q) {return (q.w*x == w*q.x) && (q.w*y == w*q.y);}
  public boolean left(Point p) {return dot(p) > 0; }
  public boolean right(Point p) {return dot(p) < 0; }

  public static double det(Homog p, Homog q, Homog r) { 
    return p.w*q.perpdot(r) - q.w*p.perpdot(r) + r.w*p.perpdot(q);
  }
  public static boolean ccw(Homog p, Homog q, Homog r) { 
    return det(p, q, r) > 0; 
  }
  public static boolean cw(Homog p, Homog q, Homog r) { 
    return det(p, q, r) < 0; 
  }

  public java.awt.Point toScreen() { 
    return new java.awt.Point((int) (x/w), (int) (-y/w));
  }
  public Point toPoint() {return new Point(x/w, y/w);}
  public Homog meet(Homog p) {
    return new Homog(x*p.y - y*p.x, p.w*y - w*p.y, w*p.x - p.w*x);
  }
  public Homog meet(Point p) {
    return new Homog(x*p.y - y*p.x, y - w*p.y, w*p.x - x);
  }
  static Homog bisect(Homog l, Homog m){
    System.out.println("bisect " + l + m);
    Homog ip = l.meet(m);
    System.out.println("ip> " + ip + ip.toPoint());
    if (ip.w == 0) { /* parallel segments, must be opposite or colinear */
      m.w = (m.w + l.w) / 2.0;
      System.out.println(m);
      return m;
    }
    else {
      m.normalize().add(l.normalize()); /* midpt at infinity */
      m.w = 0.0;
      l = m.meet(ip); /* meet mid point with ip. */
      System.out.println("m " + m + "  l " + l + "bisect done");
      return l;
    }
  }

  public String toString() { 
    return " (" + w + "; " + x + ", " + y + ")  ";
  }
  public void draw(Graphics g) {
    toPoint().draw(g);
  }
  public void drawLine(Graphics g) {
    java.awt.Rectangle r = g.getClipRect();
    System.out.println("\n drawline" + this);
    if (r.height * Math.abs(x) > r.width * Math.abs(y)) 
      g.drawLine((int)((w - r.y*y) / -x), r.y, 
		 (int)((w - (r.y + r.height)*y) / -x), r.y + r.height);
    else
      g.drawLine(r.x, (int)((w + r.x*x) / y), 
		 r.x + r.width, (int)((w + (r.x + r.width)*x) / y));
  }
}

