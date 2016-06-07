import CompGeom.*;
import java.util.Random;

/** Implements a linear time algorithm for the visiblity polygon of
    p[0] in a given simple polyline. */

public class VPTest extends PointIOApplet { 

    final static int DELAY = 2000;

    public static void main(String args[]) {
    	makeStandalone("Visibility polygon", new VPTest(), 450,350); 
    }
    

/** Assumes that the pointlist contains a simple polygon */
    public Anim2D compute(PointList pl) { 
	VisPoly vp = new VisPoly(pl);
	animate(vp);

	if (animating()) 
	    for (int i = 0; i < pl.number(); i++) {
		vp.build(i); vp.draw(getGraphics(), true);
		try {Thread.sleep(DELAY); } 
		catch (InterruptedException e) {}
		update(getGraphics());
	    }
	Random rnd = new Random();
	int i = java.lang.Math.abs(rnd.nextInt() % pl.number());
	System.out.println("" + i + " " + pl.number());
	//i = 80;
	vp.build(i);
	//System.out.println(vp.toString());
	return vp;
    }
}
