package CompGeom;

import java.awt.Graphics;
import java.awt.Color;

final public class DecompPoly extends Anim2D {
	static int c = 0;

	private PointList sp;		// the polygon
	private int n;		// number of vertices
	private SubDecomp subD;	// the subproblems in  n x r space

	private int reflexFirst;	// for reflexIter
	private int reflexNext[];	
	private boolean reflexFlag[];

	final static int DELAY = 100;	// time for animation

	public DecompPoly(PointList pl) { 
		sp = pl;
		n = sp.number();
	}

	public void init() {
		initReflex();
		subD = new SubDecomp(reflexFlag);
		initVisibility();
		initSubproblems();
	}

	public boolean reflex(int i) { return reflexFlag[i]; }

	private void initReflex() {
		reflexFlag = new boolean[n];
		reflexNext = new int[n];

		int wrap = 0;	/* find reflex vertices */
		reflexFlag[wrap] = true;	// by convention
		for (int i = n-1; i > 0; i--) {
			reflexFlag[i] = Point.right(sp.p(i-1), sp.p(i), sp.p(wrap));
			wrap = i;
		}

		reflexFirst = n;		// for reflexIter
		for (int i = n-1; i >= 0; i--) {
			reflexNext[i] = reflexFirst;
			if (reflex(i)) { reflexFirst = i; }
		}
		
		for (int i = 0; i<n; i++) System.out.print(" " + reflexNext[i]);
		System.out.println();
	}

	/* a cheap iterator through reflex vertices; each vertex knows the
	index of the next reflex vertex. */
	public int reflexIter() { return reflexFirst; } 
	public int reflexIter(int i) { // start w/ i or 1st reflex after...
		if (i <= 0) return  reflexFirst; 
		if (i > reflexNext.length) return reflexNext.length;
		return reflexNext[i-1];
	}
	public int reflexNext(int i) { return reflexNext[i]; } 


	public final static int INFINITY = 100000;
	public final static int BAD = 999990;
	public final static int NONE = 0;

	public boolean visible(int i, int j) { return subD.weight(i,j) <  BAD; }

	public void initVisibility() { // initReflex() first
		if (animating()) 
		animGraphics.setColor(Color.yellow);
		VisPoly vp = new VisPoly(sp);
		for (int i = reflexIter(); i < n; i = reflexNext(i)) {
			vp.build(i);
			while (!vp.empty()) {
				int j = vp.popVisible() % n;
				if (j < i) subD.setWeight(j, i, INFINITY);
				else subD.setWeight(i, j, INFINITY);
				if (animating()) 
				animGraphics.drawLine(sp.p(i).x(), sp.p(i).y(), 
				sp.p(j).x(), sp.p(j).y());
			}
		}
		if (animating()) {
			animGraphics.setColor(Color.blue);
			try { Thread.sleep(DELAY); 
			} catch(InterruptedException e) {
			}
		}
	}

	private void setAfter(int i) { // i reflex
		assert(reflex(i), "non reflex i in setAfter("+i+")");
		subD.setWeight(i, i+1, 0);
		if (visible(i,i+2)) subD.init(i, i+2, 0, i+1, i+1);
	}
	private void setBefore(int i) { // i reflex
		assert(reflex(i), "non reflex i in setAfter("+i+")");
		subD.setWeight(i-1, i, 0);
		if (visible(i-2, i))  subD.init(i-2, i, 0, i-1, i-1);
	}
	
	public void initSubproblems() { // initVisibility first
		int i;

		i = reflexIter();
		if (i == 0) { setAfter(i); i = reflexNext(i); }
		if (i == 1) { subD.setWeight(0, 1, 0); setAfter(i); i = reflexNext(i); }
		while (i < n-2) { setBefore(i); setAfter(i); i = reflexNext(i); }
		if (i == n-2) { setBefore(i); subD.setWeight(i,i+1,0); i = reflexNext(i);}
		if (i == n-1) { setBefore(i); }
	}

	public void initPairs(int i, int k) { 
		subD.init(i, k);
	}

	public int guard;

	public void recoverSolution(int i, int k) { 
		int j;
		if (guard-- < 0) { System.out.println("Can't recover"+i+","+k); return;}
		if (k-i <= 1) return;
		PairDeque pair = subD.pairs(i,k);
		System.out.println(i + "," + k + "  " + pair);
		if (reflex(i)) {
			j = pair.bB();
			recoverSolution(j, k);
			if (j-i > 1) {
				if (pair.aB() != pair.bB()) {
					PairDeque pd = subD.pairs(i, j);
					pd.restore();
					while ((!pd.emptyB()) && pair.aB() != pd.aB()) pd.popB();
					assert(!pd.emptyB(), "emptied pd "+i+","+j+","+k+" "+pair.toString());
				}
				recoverSolution(i, j);
			}
		}
		else {
			j = pair.aF();
			recoverSolution(i, j);
			if (k-j > 1) {
				if (pair.aF() != pair.bF()) {
					PairDeque pd = subD.pairs(j, k);
					pd.restore();
					while ((!pd.empty()) && pair.bF() != pd.bF()) pd.pop();
					assert(!pd.empty(), "emptied pd "+i+","+j+","+k+" "+pair.toString());
				}
				recoverSolution(j, k);
			}
		}
	}

	public void typeA(int i, int j, int k) { /* i reflex; use jk */
		//    System.out.print("\nA "+i+","+j+","+k+":");
		//    assert(reflex(i), "non reflex i in typeA("+i+","+j+","+k+")");
		//    assert(k-i > 1, "too small in typeA("+i+","+j+","+k+")");
		if (!visible(i,j)) return;
		int top = j;
		int w = subD.weight(i,j);
		if (k-j > 1) {
			if (!visible(j,k)) return;
			w += subD.weight(j, k) + 1;
		}
		if (j-i > 1) {		// check if must use ij, too.
			PairDeque pair = subD.pairs(i, j);
			if (!Point.left(sp.p(k), sp.p(j), sp.p(pair.bB()))) {
				while (pair.more1B()
				&& !Point.left(sp.p(k), sp.p(j), sp.p(pair.underbB())))
				pair.popB();
				if ((!pair.emptyB()) 
						&& !Point.right(sp.p(k), sp.p(i), sp.p(pair.aB())))
				top = pair.aB();
				else w++;		// yes, need ij. top = j already
			} else w++;		// yes, need ij. top = j already
		}
		update(i,k, w, top, j);
	}

	public void typeB(int i, int j, int k) { /* k reflex, i not. */
		//    System.out.print("\nB "+i+","+j+","+k+":");
		if (!visible(j,k)) return;
		int top = j;
		int w = subD.weight(j,k); 
		if (j-i > 1) {
			if (!visible(i,j)) return;
			w += subD.weight(i, j) + 1;
		}
		if (k-j > 1) {		// check if must use jk, too.
			PairDeque pair = subD.pairs(j, k);
			if (!Point.right(sp.p(i), sp.p(j), sp.p(pair.aF()))) {
				while (pair.more1()
				&& !Point.right(sp.p(i), sp.p(j), sp.p(pair.underaF())))
				pair.pop();
				if ((!pair.empty()) 
						&& !Point.left(sp.p(i), sp.p(k), sp.p(pair.bF()))) 
				top = pair.bF();
				else w++;			// yes, use jk. top=j already
			} else w++;			// yes, use jk. top=j already
		}
		update(i, k, w, j, top);
	}


	/* We have a new solution for subprob a,b with weight w, using
	i,j.  If it is better than previous solutions, we update. 
	We assume that a<b and i < j.
*/
	public void update(int a, int b, int w, int i, int j) {
		//c++;
		//if (c < 40) System.out.println("update("+a+","+b+" w:"+w+" "+i+","+j+")");
		int ow = subD.weight(a,b);
		if (w <= ow) {
			PairDeque pair = subD.pairs(a, b);
			if (w < ow) { pair.flush(); subD.setWeight(a,b, w); }
			pair.pushNarrow(i, j);
		}
	}

	public void assert(boolean flag, String s) {
		if (!flag) System.out.println("ASSERT FAIL: "+s);
	}

	private void drawDiagonal(Graphics g, boolean label, int i, int k) {
		System.out.println("diag " + i + "-" + k);
		g.drawLine(sp.p(i).x(), sp.p(i).y(), sp.p(k).x(), sp.p(k).y());
		/*if (label && (reflex(i) || reflex(k)))
		g.drawString(Integer.toString(subD.weight(i,k)), 
		(sp.p(i).x()+sp.p(k).x())/2, (sp.p(i).y()+sp.p(k).y())/2);*/
	}

	private void drawHelper(Graphics g, boolean label, int i, int k) {
		int j; 
		boolean ijreal = true, jkreal = true;
		if (k-i <= 1) return;
		PairDeque pair = subD.pairs(i,k);
		if (reflex(i)) { j = pair.bB(); ijreal = (pair.aB() == pair.bB()); } 
		else { j = pair.aF(); jkreal = (pair.bF() == pair.aF()); }

		if (ijreal) drawDiagonal(g, label, i, j);
		else if (label) { 
			g.setColor(Color.orange); 
			//drawDiagonal(g, label, i, j);
			g.setColor(Color.blue);
		}

		if (jkreal) drawDiagonal(g, label, k, j);
		else if (label) { 
			g.setColor(Color.orange); 
			//drawDiagonal(g, label, j, k);
			g.setColor(Color.blue);
		}

		if (guard-- < 0) { 
			System.out.println("Infinite Loop drawing"+i+","+k); 
			return;
		} 
		drawHelper(g, label, i, j);
		System.out.println("poly");
		drawHelper(g, label, j, k);
	}


	public void draw(Graphics g, boolean label) {
		sp.drawPolygon(g, sp.number());
		if (animating()) {
			for (int i = reflexIter(); i < sp.number(); i = reflexNext(i)) 
			sp.p(i).drawCirc(animGraphics, 5);
		}
		guard = 3*n;
		drawDiagonal(g, label, 0, sp.number()-1);
		drawHelper(g, label, 0, sp.number()-1);
	}

	public String toString() {
		StringBuffer s = new StringBuffer();
		s.append(sp.number()+": "+sp.toString());
		return s.toString();
	}
}


/* this class stores all subproblems for a decomposition by dynamic 
programming.  
It uses an indirect addressing into arrays that have all the
reflex vertices first, so that I can allocate only O(nr) space.
*/
final class SubDecomp {
	private int wt[][];
	private PairDeque pd[][];
	private int rx[];		// indirect index so reflex come first

	SubDecomp(boolean [] reflex) {
		int n = reflex.length, r = 0;

		rx = new int[n];

		for (int i = 0; i < n; i++) 
		if (reflex[i]) rx[i] = r++; 

		int j = r;
		for (int i = 0; i < n; i++) 
		if (!reflex[i]) rx[i] = j++;

		wt = new int[n][];
		pd = new PairDeque[n][];
		for (int i = 0; i < r; i++) {
			wt[i] = new int[n];
			for (j = 0; j < wt[i].length; j++) wt[i][j] = DecompPoly.BAD;
			pd[i] = new PairDeque[n];
		}
		for (int i = r; i < n; i++) {
			wt[i] = new int[r];
			for (j = 0; j < wt[i].length; j++) wt[i][j] = DecompPoly.BAD;
			pd[i] = new PairDeque[r];
		}
		
		//for (int i=0; i<rx.length; i++) System.out.print(" " + rx[i]);
		//System.out.println();
	}
	public void setWeight(int i, int j, int w) { wt[rx[i]][rx[j]] = w; }
	public int weight(int i, int j) { return wt[rx[i]][rx[j]]; }
	public PairDeque pairs(int i, int j) { return pd[rx[i]][rx[j]]; }
	public PairDeque init(int i, int j) {
		return pd[rx[i]][rx[j]] = new PairDeque(); 
	}
	public void init(int i, int j, int w, int a, int b) {
		setWeight(i,j,w); init(i,j).push(a,b);
	}
}
