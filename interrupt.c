
#include "MCIMX6Y2.h"
//define interrupt type

typedef struct _sys_irq_handle
{
    system_irq_handler_t irqHandler; 
    void *userParam;                 
} sys_irq_handle_t;

static unsigned int irqNesting;

static sys_irq_handle_t irqTable[NUMBER_OF_INT_VECTORS];


void int_init(void)
{
	GIC_Init(); 						
	system_irqtable_init();				
}


void system_irqtable_init(void)
{
	unsigned int i = 0;
	irqNesting = 0;
	
	for(i = 0; i < NUMBER_OF_INT_VECTORS; i++)
	{
		irqTable[i].irqHandler = default_irqhandler;
		irqTable[i].userParam = NULL;
	}
}


void system_register_irqhandler(IRQn_Type irq, system_irq_handler_t handler, void *userParam) 
{
	irqTable[irq].irqHandler = handler;
  	irqTable[irq].userParam = userParam;
}


void system_irqhandler(unsigned int giccIar) 
{

   uint32_t intNum = giccIar & 0x3FFUL;
   
   if ((intNum == 1023) || (intNum >= NUMBER_OF_INT_VECTORS))
   {
	 	return;
   }
 
   irqNesting++;

   irqTable[intNum].irqHandler(intNum, irqTable[intNum].userParam);
 
   irqNesting--;	

}


void default_irqhandler(unsigned int giccIar, void *userParam) 
{
	while(1) 
  	{
   	}
}



