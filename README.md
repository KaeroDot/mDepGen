# prubeh
1. najit vsechny .m v zadanem adresari a podadresarich
2. v .m najit vsechny function XX() a addpath(X)
3. pro vsechny addpath rekurze na bod 1.
5. v .m najit vsechna volani _nalezenych_ funkci 
        (jine funkce v grafu nebudou - tedy i standartni funkce octave, ale mohlo by to byt jako
        parametr?)
6. vyresit zalezitosti
7. vykreslit graf


# je treba:
vytvorit pro kazdy soubor seznam funkci a co ktera fce vola

a pak pro seznam fci delat rekurzi s pamatovanim si cesty, a pokud najde nasledujici volani v ceste,
tak je to rekurzivni volani, dat cervenou sipku a nepokracovat, tedy ukoncit stavajici strom rekurze

## funkce:
- najit vsechny .m
- najit vsechny fce v .m
- hlavni rekurzivni kreslici graf


# problemy
- nevim jak dela rekurze
- nevim jak vyresi zavislosti
- jak odhalit precedence volanych funkci?
- nikdy to nenajde externi funkce volane jako _funkce_ misto _funkce()_

# ponzamky
- kruhovou rekurzi ukoncuje limitem

# vlastnosti:
## Specials - mfilenames a ty zadane primo.
nezere skripty



# expectations:
- only one function definition per line
- can be multiple function calls per line
- function call has to have parenthesis like Call(), or at least Call(, but not Call. This can be
  overcome by setting Call to Specials
