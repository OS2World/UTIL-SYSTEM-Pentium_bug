#include <iostream.h>
#include <math.h>
#include <iomanip.h>

void main() {
	double x,y,z;
    x = 4195835.0;
    y = 3145727.0;
/*
  Divide x by y
  The correct answer is 1.333 820 449 136 241. Bad Pentiums'll return
  1.333 739 068 902 038. That's wrong.
*/
   z = x - (x / y) * y ;

   if ( fabs(z) >= 1.e-1)  {
   	  cout << " This CPU has the FDIV bug " << endl;
      cout << " 4195835 / 3145727 should equal 1.333820449136241 " 
           << endl <<  " while your CPU yields " ;
      cout <<  "         " << setprecision(16)
           << x/y << endl ;
     }      
   else
   	  cout << "This CPU does not have the FDIV bug " << endl;

/*
   Another example 
   cout << (1.0/824633702449.0)*824633702449.0 << " should be 1" << endl ;
   cout << 824633702449.0 - (1.0/824633702449.0)*824633702449.0*824633702449.0
        << " should be 0" ;
*/
       return;
}
