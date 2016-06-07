import CompGeom.*;
import java.io.*;

/** Implements the dynamic programming algorithm for 
minimum convex decomposition of a simple polygon. */
public class MCD extends PointIOApplet {

	public static void main(String args[]) {
		makeStandalone("Min convex decomp of simple polygon", new MCD(), 450,350); 
		
		//PrintStream redirOut = new PrintStream(new FileOutputStream("log.txt"));
		//System.out = redirOut;
	}


	/** Assumes that the point list contains at least three points */
	public Anim2D compute(PointList pl) {
		int type;
		int i, k, n = pl.number();
		DecompPoly dp = new DecompPoly(pl);
		animate(dp);
		dp.init();

		
		

		for (int l = 3; l < n; l++) {
			for (i = dp.reflexIter(); i + l < n; i = dp.reflexNext(i))
			{
				System.out.println("reflex: " + i + " vis: " + dp.visible(i, i+l) + " " + pl.p(i));
				//if (i > 70) return dp;
				if (dp.visible(i, k = i+l)) {
					dp.initPairs(i, k);
					if (dp.reflex(k)) 
					for (int j = i+1; j < k; j++) dp.typeA(i, j, k);
					else {
						for (int j = dp.reflexIter(i+1); j < k-1; j = dp.reflexNext(j)) 
						dp.typeA(i, j, k);
						dp.typeA(i, k-1, k); // do this, reflex or not.
					}
				}
			}
			
			for (k = dp.reflexIter(l); k < n; k = dp.reflexNext(k)) 
			if ((!dp.reflex(i = k-l)) && dp.visible(i, k)) {
				dp.initPairs(i, k);
				dp.typeB(i, i+1, k); // do this, reflex or not.
				for (int j = dp.reflexIter(i+2); j < k; j = dp.reflexNext(j)) 
				dp.typeB(i, j, k);
			}
		}
		dp.guard = 3*n;
		dp.recoverSolution(0, n-1);
		
		/*
	PairDeque pd = new PairDeque();
	pd.push(-1, -2);
	pd.push(0, 1);
	trace(pd);
	pd.push(0, 2);
	trace(pd);
	pd.push(2, 4);
	trace(pd);
	pd.pushNarrow(5, 4);
	trace(pd);
	trace(pd.aF());
	trace(pd.bF());
	trace(pd.aB());
	trace(pd.bB());
	trace(pd);
	pd.pop();
	pd.popB();
	trace(pd);
	trace(pd.underbB());
	*/
		
		return dp;
	}

	public void trace(Object o) {
		System.out.println(o.toString());
	}
}
