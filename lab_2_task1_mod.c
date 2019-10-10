// mod.c

# include <stdio.h>
# include <stdlib.h>

int gcd (int a, int b);

int main (void) {
	// % is only neg if LHS is neg
	printf ("%d \n", ((19) % (10)));
	printf ("%d \n", ((-19) % (-10)));
	printf ("%d \n", ((-19) % (10)));
	printf ("%d \n\n", ((19) % (-10)));
	printf ("%d \n", gcd(25,30));
	printf ("%d \n", gcd(-25,-30));
	printf ("%d \n", gcd(25,-30));
	printf ("%d \n", gcd(-25,30));
	return 0;
}

int gcd (int a, int b) {
	printf ("\t a is %d \n", a);
	printf ("\t b is %d \n", b);
	if (b != 0) {
		return gcd (b, a%b);
	} else {
		return a;
	}
}
