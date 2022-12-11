.text

.balign 0x20
.global _freertos_vector_table
_freertos_vector_table:
    b .
    b .
    b FreeRTOS_SWI_Handler
    b .
    b .
    b .
    b FreeRTOS_IRQ_Handler
