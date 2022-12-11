#define ENTRY_SIZE   (0x80)

.balign 0x800
.global _freertos_vector_table
_freertos_vector_table:
/* 
 * EL1 with SP0
 */  
.balign ENTRY_SIZE
curr_el_sp0_sync:        
    b	FreeRTOS_SWI_Handler
.balign ENTRY_SIZE
curr_el_sp0_irq:  
    b   FreeRTOS_IRQ_Handler
.balign ENTRY_SIZE
curr_el_sp0_fiq:         
    b	.
.balign ENTRY_SIZE
curr_el_sp0_serror:      
    b	.
          

/* 
 * EL1 with SPx
 */  
.balign ENTRY_SIZE  
curr_el_spx_sync:        
    b   FreeRTOS_SWI_Handler	
.balign ENTRY_SIZE
curr_el_spx_irq:       
    b   FreeRTOS_IRQ_Handler
.balign ENTRY_SIZE
curr_el_spx_fiq:         
    b   .
.balign ENTRY_SIZE
curr_el_spx_serror:      
    b	.         

/* 
 * Lower EL using AArch64
 */  

.balign ENTRY_SIZE
lower_el_aarch64_sync:
    b .
.balign ENTRY_SIZE
lower_el_aarch64_irq:    
    b .
.balign ENTRY_SIZE
lower_el_aarch64_fiq:    
    b	.
.balign ENTRY_SIZE
lower_el_aarch64_serror: 
    b	.          

/* 
 * Lower EL using AArch32
 */  
.balign ENTRY_SIZE   
lower_el_aarch32_sync:   
    b	.
.balign ENTRY_SIZE
lower_el_aarch32_irq:    
    b	.
.balign ENTRY_SIZE
lower_el_aarch32_fiq:    
    b	.
.balign ENTRY_SIZE
lower_el_aarch32_serror: 
    b	.

.balign ENTRY_SIZE  