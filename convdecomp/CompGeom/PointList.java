package CompGeom;

import java.util.Random;
import java.awt.Graphics;

public class PointList extends Anim2D {
  public PointList(int n) {
    counter = 0;
    p = new Point[n];
  }
  public PointList() { this(100); }
/** copy array/share points constructor */
  public PointList(PointList pl) { 
    this(pl.counter);
    counter = pl.counter;
    for (int i = 0; i < counter; i++) p[i] = pl.p(i); /* share points */
  }

  private Point[] p;
  private int counter;
  
  final public Point p(int i) { return p[i]; }
  final public Point pn(int i) { return p[i%number()]; }

  final public int number() { return counter; }
  final protected void setnumber(int c) { counter = c; }
  final public boolean isEmpty() { return counter <= 0; };
  final public void truncate(int c) { 
    if (c > p.length) throw new java.lang.IndexOutOfBoundsException(
			                  "PointList too short for truncation");
    else setnumber(c); 
  }

  protected void dr() { if (animating()) draw(animGraphics, true); }
  public void add(int x, int y) { p[counter++] = new Point(x, y); dr(); }
  public void add(Point pt) { p[counter++] = pt; dr(); }
  final public void swap(int i, int j) { 
      Point tmp = p[i]; p[i] = p[j]; p[j] = tmp; dr(); }
  public Point last() { return p[counter-1]; };
  public Point nlast() { return p[counter-2]; };
  public Point deleteLast() { if (!isEmpty()) counter--; return p[counter]; }
  public int delete(int i) { swap(i, counter-1); deleteLast(); return i; }
  public void removeAll() { counter = 0; };

  public PointList random(int n, double width, double height) {
    Random rnd = new Random();
    counter = n;
    if (p.length < n) p = new Point[n];
    for (int i=0; i < n; i++) 
      p[i] = new Point(rnd.nextDouble() * (width-5), 
		       -rnd.nextDouble() * (height-15));
    return this;
  }

  final public int leftmost() {
    int min = 0;
    for (int i = 1; i < number(); i++)  /* Find leftmost point */
      if (p(i).less(p(min))) min = i;
    if (animating()) p(min).drawCirc(animGraphics, 5); dr(); 
    return min;
  }

  final public int extreme(Point dir) { return extreme(dir, 0, number()); }

  final public int extreme(Point dir, int m, int limit) { 
    double di, dm = p(m).dot(dir);
    for (int i = m+1; i < limit; i++)  {/* Find leftmost point */
      di = p(i).dot(dir);
      if ((di > dm) || ((di == dm) && (dir.perpdot(p(m), p(i)) > 0))) {
	dm = di; m = i; 
      }
    }
    if (animating()) { dr(); 
      p(m).drawCirc(animGraphics, 5);
      dir.drawVector(animGraphics, p(m));
    }
    return m;
  }

  public void insertionsort() {
    int j;
    Point tmp;
    for (int i = 1; i < number(); i++) {
      tmp = p(i);
      if (tmp.less(p(0))) {
	for (j = i-1; j >= 0; j--) p[j+1] = p(j);
	p[0] = tmp;
      }
      else {
	j = i-1;
	while (tmp.less(p(j))) { p[j+1] = p(j); j--; }
	p[j+1] = tmp;
      }
    }
    dr(); 
  }

   /* Quick Sort implementation
    */
  public void quicksort() { quickSort(0, number()-1); }

  private void quickSort(int left, int right)
   {
      int leftIndex = left;
      int rightIndex = right;
      Point partionElement;
      if ( right > left)
      {

         /* Arbitrarily establishing partition element as the midpoint of
          * the array.
          */
         partionElement = p(( left + right ) / 2);

         // loop through the array until indices cross 
         while( leftIndex <= rightIndex )
         {
            /* find the first element that is greater than or equal to 
             * the partionElement starting from the leftIndex.
             */
            while( (leftIndex < right) &&  p(leftIndex).less(partionElement) )
               ++leftIndex;

            /* find an element that is smaller than or equal to 
             * the partionElement starting from the rightIndex.
             */
            while( (rightIndex > left) && partionElement.less(p(rightIndex)) )
               --rightIndex;

            // if the indexes have not crossed, swap
            if( leftIndex <= rightIndex ) 
            {
               swap(leftIndex, rightIndex);
               ++leftIndex;
               --rightIndex;
            }
         }

         /* If the right index has not reached the left side of array
          * must now sort the left partition.
          */
         if( left < rightIndex ) quickSort( left, rightIndex );

         /* If the left index has not reached the right side of array
          * must now sort the right partition.
          */
         if( leftIndex < right ) quickSort(leftIndex, right );
      }
      dr(); 
   }

  final public void drawPolyline(Graphics g, int n) {
    if (n > 1) 
      for (int i=1; i<n; i++)
	g.drawLine(p(i-1).x(), p(i-1).y(), p(i).x(), p(i).y());
  }

  final public void drawPolygon(Graphics g, int n) {
    if (n > 2) g.drawLine(p(n-1).x(), p(n-1).y(), p(0).x(), p(0).y());
    drawPolyline(g, n);
  }

  public void draw(Graphics g, boolean label) {
    for (int i=0; i< number(); i++)
      g.fillOval(p(i).x()-2, p(i).y()-2, 4, 4);
    if (label)
      for (int i=0; i< number(); i++)
	g.drawString(Integer.toString(i), p(i).x(), p(i).y());
  }

  public String toString() {
    StringBuffer s = new StringBuffer();
    for (int i = 0; i < number(); i++)
      s.append(p(i).toString());
    return s.toString();
  }
}
