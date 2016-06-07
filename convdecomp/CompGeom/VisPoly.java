package CompGeom;

import java.awt.Graphics;
import java.awt.Color;

/** Implements a linear time algorithm for the visiblity polygon of
	sp[0] in a given simple polyline. */

public class VisPoly extends Anim2D { 
	private PointList sp;	// simple polygon
	private Point org;		// origin of visibility polygon
	private int v[];		// stack holds indices of visibility polygon
	private int vtype[];	// types of vp vertices
	private int vp;		// stack pointer to top element
	
	public VisPoly(PointList pl) {
		int n = pl.number();
		sp = pl;
		v = new int[n];
		vtype = new int [n];
		vp = -1;
	}

	
	/** Build the visibility polygon for a given vertex */
	
	public void build(int orgIndex) {
		Homog edgej;		// during the loops, this is the line p(j-1)->p(j)
		org = sp.p(orgIndex);
		vp = -1;
		int j = orgIndex;
		push(j++, RWALL);	// org & p[1] on VP
		do {			// loop always pushes pj and increments j.
			push(j++, RWALL);
			if (j >= sp.number()+orgIndex) return; // we are done.
			edgej = p(j-1).meet(p(j));
			//System.out.println("" + j + " " + edgej + " " + p(j) + p(j-1) + orgIndex);
			if (edgej.left(org)) {
				//System.out.println("left org");
				continue; // easiest case: add edge to VP.
			}
			// else pj backtracks, we must determine where
			if (!edgej.left(p(j-2))) {// pj is above last VP edge
				//System.out.println("!left j-2");
				j = exitRBay(j, top(), Homog.INFINITY);
				push(j++, RLID); continue;  // exits bay; push next two
			}
			
			saveLid();		// else pj below top edge; becomes lid or pops
			do {		// pj hides some of VP; break loop when can push pj.
				//System.out.print("do j:"+j+" lid:"+LLidIdx+" "+RLidIdx+toString());
				if (Point.left(org, top(), p(j))) {// saved lid ok so far...
					if (Point.right(p(j), p(j+1), org)) j++; // continue to hide
					else if (edgej.left(p(j+1))) { // or turns up into bay
						j = exitLBay(j, p(j), p(LLidIdx).meet(p(LLidIdx-1))) +1; }
					else {	// or turns down; put saved lid back & add new VP edge 
						restoreLid(); push(j++, LWALL); break; }
					edgej = p(j-1).meet(p(j)); // loop continues with new j; update edgej
				}
				else		// lid is no longer visible
				if (!edgej.left(top())) { // entered RBay, must get out
					//System.out.println("RLid not saved");
					assert((RLidIdx != NOTSAVED), 
					"no RLid saved " +LLidIdx+RLidIdx+toString());
					j = exitRBay(j, top(), edgej.neg()); // exits bay;
					push(j++, RLID); break; } // found new visible lid to add to VP.
				else saveLid(); // save new lid from VP; continue to hide VP.
			} while (true);
			//System.out.print("exit j:"+j+" lid:"+LLidIdx+" "+RLidIdx+toString());
		} while (j < sp.number()+orgIndex); // don't push origin again.
	}


	public static void assert(boolean flag, String s) {
		if (!flag) System.out.println("ASSERT FAIL: "+ s);
	}
	public boolean empty() { return vp < 0; }
	
	public int popVisible() { 
		while ((vtype[vp] == RLID)||(vtype[vp] == LLID)) vp--;
		return v[vp--]; 
	}

	/** helper functions */

	final private Point p(int j) { return sp.pn(j); }
	final private Point top() { return p(v[vp]); }
	final private Point ntop() { return p(v[vp-1]); }
	final private void push(int idx, int t) { v[++vp] = idx; vtype[vp] = t; }    
	
	
	/** exit a bay: proceed from j, j++, .. until exiting the bay defined
	to the right (or left for exitLBay) of the line from org through
	point bot to line lid.  Return j such that (j,j+1) forms new lid
	of this bay.  Assumes that pl.p(j) is not left (right) of the line
	org->bot.  
*/
	int exitRBay(int j, Point bot, Homog lid) {
		int wn = 0;		// winding number
		Homog mouth = org.meet(bot);
		boolean lastLeft, currLeft = false;
		//System.out.println("rbay");
		while (++j < 3*sp.number()) {
			lastLeft = currLeft; 
			currLeft = mouth.left(p(j));
			//System.out.println(j + " " + currLeft + " " + lastLeft);
			if ((currLeft != lastLeft) // If cross ray org->bot, update wn
					&& (Point.left(p(j-1), p(j),org) == currLeft)) { 
				//System.out.println(j + " curr != last");
				if (!currLeft) wn--;
				else if (wn++ == 0) { // on 0->1 transitions, check window
					Homog edge = p(j-1).meet(p(j));
					//System.out.println(j + " " + edge.left(bot) + " " + (!Homog.cw(mouth, edge, lid)));
					if (edge.left(bot) && !Homog.cw(mouth, edge, lid))
					return j-1; // j exits window!
				}
			}
		}
		
		System.out.println("ERROR: We never exited RBay "+bot+lid+wn+"\n"+toString());
		return j;
	} 

	int exitLBay(int j, Point bot, Homog lid) {
		int wn = 0;		// winding number
		Homog mouth = org.meet(bot);
		boolean lastRight, currRight = false; // called with !right(org,bot,pj)
		//System.out.println("lbay");
		while (++j < 3*sp.number()) {
			lastRight = currRight; 
			currRight = mouth.right(p(j));
			//System.out.println(j + " " + currRight + " " + lastRight);
			if ((currRight != lastRight) // If cross ray org->bot, update wn
					&& (Point.right(p(j-1), p(j), org) == currRight)) { 
				//System.out.println(j + " curr != last");
				if (!currRight) wn++;
				else if (wn-- == 0) { // on 0->-1 transitions, check window
					Homog edge = p(j-1).meet(p(j));
					//System.out.println(j + " " + edge.right(bot) + " " + (!Homog.cw(mouth, edge, lid)));
					if(edge.right(bot) && !Homog.cw(mouth, edge, lid))
					return j-1; // j exits window!
				}
			}
		}
		
		System.out.println("ERROR: We never exited LBay "+bot+lid+wn+"\n"+toString());
		return j;
	} 

	
	/**    polygon vertex types:    LLID-------------------RLID
									|            |
									|            |
							--------LWALL        RWALL---------
*/
	static final int RLID  = 0;	
	static final int LLID  = 1;
	static final int RWALL = 2;
	static final int LWALL = 3;

	static final Color vtypeLUT[] = {Color.yellow, Color.black, 
		Color.green, Color.blue};
	static final String vtypeString[] = {"RL ", "LL ", "RW ", "LW "};

	/** Proceedures to keep the lid above the current vertex on top of the stack, 
	leaving the top() as a vertex of the VP that is also a vertex of sp.
	These use global status variables to keep the code  for build() cleaner.
*/
	static final int NOTSAVED = -1; // flag for when we don't have a RLidIdx
	private int LLidIdx, RLidIdx;
	final private void saveLid() { 
		//System.out.print("saveLid " + vp + "\n");
		//System.out.print("   " + vtypeString[vtype[vp]] + "\n");
		if (vtype[vp] == LWALL) vp--; // for LWALL, lid is previous two
		LLidIdx = v[vp--];
		//System.out.print("   " + vtypeString[vtype[vp]] + "\n");
		if (vtype[vp] == RLID) {
			RLidIdx = v[vp--]; // if not RLID, just leave on top().
		}
		else {
			//System.out.println(RLidIdx + " not saved");
			RLidIdx = NOTSAVED;
		}
		//System.out.println("    -- " + LLidIdx + " " + RLidIdx);
	}
	
	final private void restoreLid() {
		//System.out.print("restoreLid "+LLidIdx+","+RLidIdx+ toString());
		if (RLidIdx != NOTSAVED) push(RLidIdx, RLID); 
		push(LLidIdx, LLID);
	}


	public void draw(Graphics g, boolean label) {
		g.setColor(Color.red);
		sp.drawPolygon(g, sp.number());
		if (empty()) return;

		PointList vis = new PointList(400);
		g.setColor(Color.black);
		//org.drawDot(g, 5);
		Point last = p(v[vp]);
		for (int i = 0; i <= vp; i++) {
			g.setColor(Color.blue);
			if (vtype[i] == RLID) {
				Homog q = org.meet(last)
					.meet(
						p(v[i]).meet(p(v[i+1])
					));
				g.drawLine(last.x(), last.y(), q.x(), q.y()); 
				vis.add(last.x(), last.y());
				vis.add(q.x(), q.y());
			}
			else if (vtype[i] == LWALL) {
				Homog q = org.meet(p(v[i])).meet(p(v[i-2]).meet(p(v[i-1])));
				g.drawLine(q.x(), q.y(), p(v[i]).x(), p(v[i]).y());
				vis.add(q.x(), q.y());
				vis.add(p(v[i]).x(), p(v[i]).y());
			}
			else {
				g.drawLine(last.x(), last.y(), p(v[i]).x(), p(v[i]).y());
				vis.add(last.x(), last.y());
				vis.add(p(v[i]).x(), p(v[i]).y());
			}
			last = p(v[i]);
			g.setColor(vtypeLUT[vtype[i]]);
			last.drawDot(g);
		}
		
		Point p0 = p(v[0]);
		g.setColor(Color.black);
		Homog m = p0.meet(p(v[2]));
		g.drawLine(p0.x(), p0.y(), m.x(), m.y());
		
		for (int i = 0; i<vis.number(); i++) {
			//System.out.println(vis.p(i).toString());
		}
	}
	
	public String toString() {
		StringBuffer s = new StringBuffer();
		s.append("VP "+ vp+": ");
		for (int i = 0; i <= vp; i++) s.append(v[i]+vtypeString[vtype[i]]);
		s.append("\nVP:");
		for (int i = 0; i <= vp; i++) s.append(p(v[i]).toString());
		s.append("\nSP:");
		s.append(sp.toString());
		s.append("\nV:");
		for (int i = 0; i <= vp; i++) s.append(v[i]);
		s.append("\n");
		return s.toString();
	}
}
