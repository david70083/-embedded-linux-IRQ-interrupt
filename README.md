**設定IRQ中斷**

1\. 彙編中定義中斷向量表
![](https://drive.google.com/file/d/1xqsGTPMwVZ42_u8z_b4_c_UlxNz5UXeG/view?usp=drive_link)

將中斷向量寫入R15(PC)，PC表示要執行的地址，每個地址相差4 bits，

ldr pc, =Reset handler 地址為0x0

ldr pc, = Undefine handler 地址為0x4

.

.

當復位中斷觸發時，cortex A會自己去執行0x0地址的程式


2.關閉I cache(指令快取)、D cache(資料快取) 和 MMU(記憶體管理單元)

先關閉IRQ再進行設定避免可能的中斷干擾，cpsid i

避免中斷時儲存到錯誤的資料。快取是由CP15控制，CP15是arm架構中協處理器，也就是系統控制寄存器(System Control Registers)，因此要關閉需要設定CP15。協處理器需要只用特殊指令進行讀取與寫入:

MRC: 將 CP15 協處理器中的暫存器資料讀取到 ARM 暫存器。

MCR: 將 ARM 暫存器的資料寫入到 CP15 協處理器暫存器。

MCR p15, &lt;opc1&gt;, &lt;Rt&gt;, &lt;CRn&gt;, &lt;CRm&gt;, &lt;opc2&gt;，opc1與opc2為操作碼，基本上都是0。CRn與CRm表示CP15寄存器的編號，Rt為我們要寫入或要讀出來的寄存器，例R0。


I cache、D cache與MMU由SCTLR控制，需要設定特定bit的值


3.設定中斷向量偏移

中斷向量偏移也是在CP15協處器中控制的，由VBAR控制，需要設定特定bit的值。設定過程需要被dsb, isb包起來，否則會有問題。

dsb: 確保前面資料都傳完才會執行

isb: 確保前面指令都傳完才會執行


4.設定SPSR指針

SPSR寄存器的內容包括了程式計數器(PC)和程式狀態暫存器(CPSR)，代表這個模式下執行的地址從SPSR地址開始，因為會用到IRQ，所以IRQ也要設定。

設定完後即可開啟IRQ中斷，cpsie i


5.設定IRQ中斷

1.儲存目前狀態的返回地址，中斷結束後要回到這個地址

2.儲存目前寄存器值R0-R3, R12

3.讀取並儲存目前的SPSR

觸發中斷前需要知道觸發的中斷ID。cortex A-7提供了1020個中斷ID，其中16個給SGI(Software-generated Interrupt)，16個給PPI(Private Peripheral Interrupt)，剩下的IC廠自行使用，imx6ULL定義了128個中斷ID。

6.使用ldr將中斷函式地址存到R2中

7.使用blx轉跳至中斷函式中

8.進入IRQ模式，把中斷ID寫入GICC_EOIR，才算是處理完該中斷，否則無法執行下一個中斷

9.把最一開始儲存的lr-4設定到pc，讓pc從lr-4繼續執行

6.初始化GIC，使用core_ca7.h中的函式GIC_Init()

7.定義中斷處裡函式

定一一個函式指針的類別

typedef void (\*system_irq_handler_t) (unsigned int giccIar, void \*param);

ex:

# include &lt;stdio.h&gt;

typedef void (\*system_irq_handler_t)(unsigned int giccIar, void \*param);

void my_irq_handler(unsigned int giccIar, void \*param) {

printf("Interrupt handler called with giccIar=%u\\n", giccIar);

}

//函式my_irq_handler的輸入要與函式指針類別system_irq_handler_t 相同

int main() {

system_irq_handler_t a = &my_irq_handler; //將a設為函式my_irq_handler的地址

a(123, NULL); //執行a則執行my_irq_handler

return 0;

}

8.建立中斷處理函式表

定義中斷處理函式結構，裡面放剛剛建立的system_irq_handler_t與傳入參數

typedef struct \_sys_irq_handle

{

system_irq_handler_t irqHandler;

void \*userParam;

} sys_irq_handle_t;

將結構宣告成陣列，大小為NUMBER_OF_INT_VECTORS=160個，16 PPI、16 SGI和128 im6ULL定義的中斷

static sys_irq_handle_t irqTable\[NUMBER_OF_INT_VECTORS\];

建立預設中斷函式

void default_irqhandler(unsigned int giccIar, void \*userParam)

{

while(1)

{

}

}

初始化所有的中斷函式

void system_irqtable_init(void)

{

unsigned int i = 0;

irqNesting = 0;

for(i = 0; i < NUMBER_OF_INT_VECTORS; i++)

{

irqTable\[i\].irqHandler = default_irqhandler;

irqTable\[i\].userParam = NULL;

}

}

設定中斷處理函式

輸入為中斷ID，要執行的函式與輸入參數

void system_register_irqhandler(IRQn_Type irq, system_irq_handler_t handler, void \*userParam)

{

irqTable\[irq\].irqHandler = handler;

irqTable\[irq\].userParam = userParam;

}

設定IRQ中斷時，會進入的中斷處理函式system_irqhandler

void system_irqhandler(unsigned int giccIar)

{

uint32_t intNum = giccIar & 0x3ff; //GICC-IAR的0-9bit才是中斷ID

if (intNum >= NUMBER_OF_INT_VECTORS) //超過中斷ID return

{

return;

}

irqTable\[intNum\].irqHandler(intNum, irqTable\[intNum\].userParam); //執行對應的中斷

irqNesting--;

}

9.設定GPIO中斷

設定GPIO中斷類型

中斷類型是由GPIO_ICR1和ICR2控制，ICR每個GPIO由兩個bit決定中斷類型

00 LOW_LEVEL

01 HIGH_LEVEL

10 RISING_EDGE

11 FALLING_EDGE

GPIO_EDGE_SEL是設定下降緣與上升緣都可以觸發，就設定成1

建立指針判斷是低16bit還是高16bit對ICR進行設定，需要注意GPIO_EDGE_SEL的優先權大於ICR，因此要把GPIOx_EDGE_SEL先設0，有需要再設成1

base->EDGE_SEL &= ~(1 << pin);

volatile uint32_t \*icr;

uint32_t icrShift;

icrShift = pin;

base->EDGE_SEL &= ~(1U << pin);

if(pin < 16) /\* 低16位 \*/

{

icr = &(base->ICR1);

}

else /\* 高16位 \*/

{

icr = &(base->ICR2);

icrShift -= 16;

}

\*icr &= ~(3 << (2 \* icrShift)); //設定成低電平觸發

GPIO使能，IMR寄存器

void gpio_enableint(GPIO_Type\* base, unsigned int pin)

{

base->IMR |= (1 << pin);

}

GPIO中斷結束寫入

與GICC_EOIR一樣，中斷結束後需要清除中斷旗標，清除中斷旗標是對ISR寄存器寫入1

base->ISR |= (1 << pin);

10.完成最終中斷函式，並將該函式使用上面的設定中斷函式設定到中斷處理函式的陣列中

void gpio1_io18_irqhandler(void)

{

static unsigned char state = 0;

delay(10);

if(gpio_pinread(GPIO1, 18) == 0)

{

state = !state;

beep_switch(state);

}

gpio_clearintflags(GPIO1, 18);

}

//GPIO1_Combined_16_31_IRQn = 99，為中斷ID

system_register_irqhandler(GPIO1_Combined_16_31_IRQn, (system_irq_handler_t)gpio1_io18_irqhandler, NULL); //設定到陣列中
