#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <stdlib.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
 
#include "pc5.h"
 
#define PIO_C5 5 // position du bit correspondant a PC5
 
void affich_bits(unsigned long val,int nb_bits)
{
	int i, blk_hexa;
 
	blk_hexa = 4;
	for(i = (nb_bits-1) ; i >= 0 ; i--){
		if (!blk_hexa){
			printf(" ");
			blk_hexa = 4;
		}
		blk_hexa--;
		printf("%d", (val >> i ) & 1);
	}
	printf("\n"); 
}
 
int main(void)
{
	int fd,i ;
	char etat_h_PIOC ;
	void *map_base ; 
	unsigned long readval, writeval, masque, valeur ;
 
	printf("\nAT91RM9200 change PC5 d etat\n\n");
 
 
    	if((fd = open("/dev/mem", O_RDWR | O_SYNC)) == -1){
		printf("PC5: Erreur en ouvrant /dev/mem\n");
		exit(-1);
	}
 
 
	/* Creation d une projection de la page memoire physique
  	correspondant aux peripheriques systeme */
	map_base = mmap(0, MAP_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, AT91_SYS & ~MAP_MASK);
	if(map_base == (void *) -1){
		printf("PC5: Erreur lors de l adressage de la memoire\n");
		close(fd);
		exit(-1);
	}
 
	/******************************
 	* lecture du registre d etat des horloges pour les peripheriques
 	* du gestionaire de consomation et activation de l horloge
 	* correspondant a PIOC si necessaire. 
 	*******************************/
 
	readval = *((unsigned long*)(map_base + ((PMC_OFFSET + PMC_PCSR) & MAP_MASK)));
 
	/* affichage de la valeur binaire */
	printf("valeur du registre PMC_PCSR = \n");
	affich_bits(readval, 32);
 
	/* test de l etat de l horge du port PIOC. activation si inactive */
 
	/* creation du masque pour lire le bit correspondant a l identifiant du PIOC */
	masque = 1 << PIOC_ID ;
 
	if((readval & masque) == 0) {
		printf("activation de l horloge pour PIOC\n");
		writeval = 1 << PIOC_ID ;
		*((unsigned long*)(map_base + ((PMC_OFFSET + PMC_PCER) & MAP_MASK))) = writeval;
		etat_h_PIOC = 0 ;
	}
	else {
		printf("l horloge pour PIOC est deja active\n");
		etat_h_PIOC = 1 ;
	}
 
	/******************************
  lecture du registre de statut du PIO, PIO_PSR, indiquant si la broche
 	est utilisee comme E/S ou comme fonction speciale d un peripherique
 	embarque.
 	*******************************/
 
	readval = *((unsigned long*)(map_base + ((PIOC_OFFSET + PIO_PSR) & MAP_MASK)));
 
	/* affichage de la valeur binaire */
	printf("\nvaleur du registre PIO_PSR = \n");
	affich_bits(readval, 32);
 
	/* test de l etat du bit 5 du registre PIO_PSR */
 
	/* creation du masque pour lire le bit correspondant a la broche desiree */
	masque = 1 << PIO_C5;
 
	if((readval & masque) == 0) {
		printf(" ! La broche %d est deja utilisee par un peripherique\n !", PIO_C5);
		printf("je n y touche pas !\n");
		if(munmap(map_base, MAP_SIZE) == -1){
			printf("Erreur en desadressant la memoire\n");
			close(fd);
			exit(-1);
		}
 
    		close(fd);
		return(0);
	}
	else {
		printf(" ! La broche %d est bien utilisee en E/S !\n", PIO_C5);
	}
 
	/******************************
  lecture du registre de statut de sortie du PIO, PIO_PSR,
  indiquant si la broche est utilisee comme entree ou comme sorite.
  Modification si necessaire.
 	*******************************/
 
	readval = *((unsigned long*)(map_base + ((PIOC_OFFSET + PIO_PSR) & MAP_MASK)));
 
	/* affichage de la valeur binaire */
	printf("\nvaleur du registre PIO_PSR = \n");
	affich_bits(readval, 32);
 
	/* test de l etat du bit 5 du registre PIO_PSR */
 
	/* creation du masque pour lire le bit correspondant a la broche desiree */
	masque = 1 << PIO_C5;
 
	if((readval & masque) == 0) {
		printf("La broche %d est utilisee comme entree\n", PIO_C5);
		printf("Modification en sortie\n");
		writeval = 1 << PIO_C5 ;
		*((unsigned long*)(map_base + ((PIOC_OFFSET + PIO_OER) & MAP_MASK))) = writeval;
	}
	else {
		printf("La broche %d est bien utilisee comme sortie\n", PIO_C5);
	}
 
	/******************************
  lecture du registre de statut de donnees du PIO, PIO_ODSR,
  indiquant si la broche est a l etat haut ou bas.
  Inversion de l etat.
 	*******************************/
 
	readval = *((unsigned long*)(map_base + ((PIOC_OFFSET + PIO_ODSR) & MAP_MASK)));
 
	/* affichage de la valeur binaire */
	printf("\nvaleur du registre PIO_ODSR = \n");
	affich_bits(readval, 32); 
 
	/* test de l etat du bit 5 du registre PIO_ODSR */
 
	/* creation du masque pour lire le bit correspondant a la broche desiree */
	masque = 1 << PIO_C5;
 
	if((readval & masque) == 0) {
		printf("La broche %d est a O\n", PIO_C5);
		printf("Inversion\n");
		writeval = 1 << PIO_C5 ;
		*((unsigned long*)(map_base + ((PIOC_OFFSET + PIO_SODR) & MAP_MASK))) = writeval;
	}
	else {
		printf("La broche %d est a 1\n", PIO_C5);
		printf("Inversion\n");
		writeval = 1 << PIO_C5 ;
		*((unsigned long*)(map_base + ((PIOC_OFFSET + PIO_CODR) & MAP_MASK))) = writeval;
	}
 
	/* destruction de la projection de la plage memoire */
	if(munmap(map_base, MAP_SIZE) == -1){
			printf("Erreur en desadressant la memoire\n");
			close(fd);
			exit(-1);
		}
	/* fermeture du fichier de memoire */
	close(fd);
 
	return(0);
}
