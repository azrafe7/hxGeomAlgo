package CompGeom;

/* This is a hybrid between a stack and a deque, for storing pairs of
integers that form non-nested intervals in increasing order, back to
front.  It is used in minimum convex decomposition.

It is assumed that pushes come first (perhaps with some pops from
pushNarrow) and happen at the front of the deque. Then two independent
front and back pointers for popping. Unlike a standard deque, front
and back don't interfere: if you pop off one side, the element is
still available for the other side.  Thus, this is more like a pair of 
stacks that have the same elements in reverse order. 
*/

final public class PairDeque {
	private int a[];		// first elts of pair
	private int b[];		// second elts of pair

	// pointers point at the valid element. I.e., if there are none, the 
	// can point off the end of the list.
	private int fp;		// front pointer
	private int bp;		// back pointer
	private int last;		// the "high-water mark" for restores

	public PairDeque(int n) { 
		last = fp = -1; 
		bp = 0; 
		a = new int[n]; b = new int[n]; 
	}

	public PairDeque() { this(4); } // try 4 pairs to start with

	public void push(int i, int j) { // we push only onto the front
		if (a.length <= ++fp) {	// make room if necessary
			a = grow(a, 2);
			b = grow(b, 2);
		}
		//if (fp >= a.length || fp < 0) {
			//System.out.println("fp:" + fp + " sizes:" + a.length + "," + b.length);
		
		//}
		a[fp] = i; 
		b[fp] = j; 
		last = fp;
	}

	public void pushNarrow(int i, int j) { // no nesting--> aF<i & bF<j
		if ((!empty()) && (i <= aF())) return; // don't push wider
		while ((!empty()) && (bF() >= j)) pop(); // pop until narrower: bF<j
		push(i, j);
	}

	private PairDeque merge(PairDeque pd) { // untested
		PairDeque tmp = new PairDeque(last + pd.last);
		bp = 0; pd.bp = 0;
		while ((!emptyB()) && !pd.emptyB()) 
		if (aB() < pd.aB()) { tmp.pushNarrow(aB(), bB()); popB(); }
		else { tmp.pushNarrow(pd.aB(), pd.bB()); pd.popB(); }
		while (!emptyB()) { tmp.pushNarrow(aB(), bB()); popB(); }
		while (!pd.emptyB()) { tmp.pushNarrow(pd.aB(), pd.bB()); pd.popB(); }
		return tmp;
	}

	public boolean empty() { return fp < 0; }
	public boolean more1() { return fp > 0; } //frontHasNext
	public void flush() { last = fp = -1; }
	public int aF() { if (fp < 0) System.out.println("fp is -1!!!"); return a[fp]; }  // frontTop
	public int underaF() { return a[fp-1]; }  // frontPeekNext
	public int bF() { return b[fp]; }  // backBottom
	public void pop() { fp--; }  
	public void restore() { bp = 0; fp = last; } // return to high-water mark

	public boolean emptyB() { return bp > last ; }
	public boolean more1B() { return bp < last; } // backHasNext
	public int aB() { return a[bp]; }   // frontBottom
	public int underbB() { return b[bp+1]; }  // backPeekNext
	public int bB() { return b[bp]; }  // backTop
	public void popB() { bp++; }

	private int[] grow(int[] a, int factor) {
		int tmp[] = a; a = new int[a.length*2]; 
		//   for (int k = 0; k < tmp.length; k++) a[k] = tmp[k]; 
		System.arraycopy(tmp, 0, a, 0, tmp.length); 
		return a;
	}

	public String toString() {
		StringBuffer s = new StringBuffer();
		s.append(fp+","+bp+","+last+": ");
		for (int i = 0; i <= last; i++) s.append(a[i]+","+b[i]+"  ");
		return s.toString();
	}
}
