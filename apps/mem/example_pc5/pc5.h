#ifndef GPIO_H
#define GPIO_H
 
/* definitions de la plage memoire
 * pour acceder aux peripheriques */
#define MAP_SIZE 4096UL	
#define MAP_MASK (MAP_SIZE - 1)
 
/* definition pour les periphs systemes AT91RM9200 */
#define AT91_SYS	0xFFFFF000
 
/* definitions du PMC pour les horloges des peripheriques */
#define PMC_OFFSET	0xC00
 
#define PMC_PCER	0x0010 // Peripheral Clock Enable Register - Write-only
#define PMC_PCDR	0x0014 // Peripheral Clock Disable Register - Write-only
#define PMC_PCSR	0x0018 // Peripheral Clock Status Register - Read-only
 
/* definition de l identifiant du PIOC */
#define PIOC_ID 	4
 
/* definitions du decalage des registres du PIO C */
#define PIOC_OFFSET 	0x800
 
/* definitions des registres des PIO utiles pour les sorties */
#define PIO_PER		0x0000 // PIO Enable Register - Write-only
#define PIO_PDR		0x0004 // PIO Disable Register - Write-only
#define PIO_PSR		0x0008 // PIO Status Register - Read-only
 
#define PIO_OER		0x0010 // PIO Output Enable Register - Write-only
#define PIO_ODR		0x0014 // PIO Output Disable Register- Write-only
#define PIO_OSR		0x0018 // PIO Output Status Register - Read-only
 
#define PIO_SODR	0x0030 // PIO Set Output Data Register - Write-only
#define PIO_CODR	0x0034 // PIO Clear Output Data Register - Write-only
#define PIO_ODSR	0x0038 // PIO Output Data Status Register - Read-only
 
#endif
