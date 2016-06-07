package CompGeom;
import java.applet.Applet;
import java.awt.*;

public abstract class CGApplet extends Applet {

  static PointList pts = new PointList(100);
  static Anim2D result = null;
  static boolean detail = false;
  static boolean animating = false;

  private Button clear_button = new Button("Clear All");
  private Button delete_button = new Button("Delete Last");
  private Button anim_button = new Button("Animate");
  private Button detail_button = new Button("Detail");
  private Button random_button = new Button("Random");
  private Button update_button = new Button("Update");

  final public boolean animating() { return animating; }

  public void init() {
    setLayout(new BorderLayout());
    setBackground(Color.white);
    setForeground(Color.black);

    Panel p=new Panel();
    addbuttons(p);
    add("South",p);
  }

  void addbuttons(Panel p) {
    p.add(clear_button);
    p.add(delete_button);
    p.add(detail_button);
    p.add(anim_button);
    p.add(random_button);
    p.add(update_button);
  }

  boolean handlebuttons(Object target){
    if (target == clear_button) { pts.removeAll(); result = null; }
    else if (target == delete_button) { pts.deleteLast(); result = null; }
    else if (target == detail_button) detail = !detail;
    else if (target == anim_button) { animating = !animating; }
    else if (target == random_button) { 
      pts.random(30, 350, 350);  result = null; 
    }
    else if (target == update_button) {
      if (!pts.isEmpty()) {
	CompGeom.Point.reset();
	result = compute(pts);
	System.out.println(CompGeom.Point.stats());
      }
    }
    else return false;
    update(getGraphics());
    return true;
  }

  public boolean action(Event e, Object obj){
    if (e.target instanceof Button) return handlebuttons(e.target);
    return true;
  }

  public boolean mouseDown(Event e, int x, int y){
    Graphics g = getGraphics();
    g.setColor(Color.black);
    g.fillOval(x-3, y-3, 6, 6);
    pts.add(x, y);
    result = null;
    repaint();
    return true;
  }

  public void animate(Anim2D pa) {
    if (animating()) pa.register(getGraphics());
  }

  public String getAppletInfo() {
    return "Computational Geometry demonstration applet\n" +
      "Jack Snoeyink\nversion 1.0 January 1996";
  }

  static public void makeStandalone(String title, PointIOApplet ap, 
			     int width, int height)
 {
    Frame f = new Frame(title);
    ap.init();
    ap.start();
    f.add("Center", ap);
    f.resize(width, height);
    f.show();
  }
//Example of use in derived class:
//public static void main(String args[]);
// { makeStandalone("Jarvis march", new Jarvis(), 350, 350); }

  public void paint(Graphics g){
    g.setColor(Color.red);
    pts.draw(g, detail);
    g.setColor(Color.blue);
    if (result != null) result.draw(g, detail);
  }

  public abstract Anim2D compute(PointList pl);
}
