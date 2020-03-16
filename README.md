# IV-Curve Tracer

Разработано устройство для автоматического снятия вольт-амперных характеристик (ВАХ) фотоэлектрических преобразователей (ФЭП) с полевым транзистором в качестве управляемой электронной нагрузки.

## Hardwire

Функциональная схема устройства автоматического снятия ВАХ солнечного модуля приведена на рисунке:

![Functional scheme](/img/ivc_tracer_func_scheme.jpg)

В качестве переменной электронной нагрузки используется полевой (MOSFET) транзистор, установленный на радиаторе для рассеивания выделяющегося тепла. Цифровой измерительный блок содержит датчики тока и напряжения, аналого-цифровые преобразователи (АЦП), цифро-аналоговый преобразователь (ЦАП) и микроконтроллер.

Напряжение затвор-исток транзистора устанавливается при помощи цифро-аналогового преобразователя. ЦАП обеспечивает изменение сопротивления перехода сток-исток транзистора в широком диапазоне: от практически нуля Ом (точка короткого замыкания) до нескольких МОм (точка холостого хода). При помощи АЦП производится оцифровка данных от датчиков тока и напряжения исследуемого солнечного модуля. Измерение тока производится с помощью интегрального датчика тока ACS712 фирмы Allegro. Для измерения напряжения используется делитель напряжения на двух резисторах.

Управляет процессом автоматического снятия ВАХ – микроконтроллер ATmega16, входящий в состав микроконтроллерного комплекта Pinboard II.

Принципиальная электрическая схема устройства:

![Functional scheme](/img/ivc_tracer_scheme.jpg)

## Firmware

### Description

Алгоритм работы микроконтроллера при автоматическом снятии ВАХ следующий: путем установки цифрового кода ЦАП задается начальное сопротивление перехода сток-исток транзистора, при этом изменяются ток и напряжение солнечного модуля в соответствии с его ВАХ. Напряжение и ток измеряются датчиками, сигналы оцифровываются с помощью АЦП и передаются в микроконтроллер, который выполняет вычисления и передает измеренные ток и напряжение на компьютер через преобразователь интерфейсов UART-USB. Затем значение ЦАП увеличивается на заданный шаг и процесс повторяется, пока не будет достигнуто конечное значение ЦАП. Начальное, конечное значение и шаг ЦАП задаются в меню настройки на жидкокристаллическом дисплее путем поворота ручки энкодера, а также через управляющую программу с компьютера.

Также доступен ручной режим снятия ВАХ. Текущие значения ЦАП устанавливаются путем поворота ручки энкодера, измеренные значения тока и напряжения отображаются на жидкокристаллическом дисплее.

### Realization

Реакция на события реализована в виде флагового автомата.

#### События

На главном экране существуют следующие события:
 - обновление информации на экране (два раза в секунду);
 - поворот ручки энкодера влево (уменьшение значения ЦАП);
 - поворот ручки энкодера вправо (увеличение значения ЦАП);
 - короткое нажатие на кнопку (вызов главного меню);
 - длительное нажатие на кнопку (запуск процедуры автоматического снятия ВАХ).

#### Главное меню

При помощи главного меню можно настроить переменные прибора. На каждом экране меню отображается имя переменной и ниже её значение. Значение регулируется при помощи поворота ручки энкодера. Переключение между экранами производится нажатием на кнопку меню.

При помощи меню можно настроить следующие переменные: `DAC_STEP`, `IVC_DAC_START`, `IVC_DAC_END`, `IVC_DAC_STEP`.

#### UART terminal

По UART доступен командный интерпретатор. По мере поступления, входящие символы добавляются в кольцевой буфер UART по прерыванию `UART Receive Complete`. При получении символа перевода каретки (CR, код 13, `\n`), возводится флаг о приёме строки. Далее управление передаётся парсеру `UART_RX_PARSE`. Запускается подпрограмма `SPLIT_LINE`, которая подготавливает командную строку в виде `команда\0[аргументы]\0`: из кольцевого буфера последовательно извлекаются символы, после первой последовательности символов (команды), отделённой пробелом, следуют опциональные аргументы, индексы начала которых добавляются в отдельный массив. Затем запускается подпрограмма `DEFINE_CMD`, которая идентифицирует команду и в случае успеха возвращает `CMD_ID` - идентификатор команды. Если ошибок не обнаружено, управление передаётся обработчику команды при помощи подпрограммы `EXEC_CMD`.

##### Список доступных команд

1. `clear` - очистка экрана
2. `reboot` - перезагрузка устройства
3. `echo` - эхо, возвращает в терминал значение своего аргумента
4. `set` - изменение значения переменной (имеет два аргумента: имя переменной и новое значение)
5. `get` - считывание значения переменной (при отправке без аргумента, либо при аргументе `ALL`, выводит список "имя=значение" переменных; при указании конкретного имени переменной выводит значение этой переменной)
6. `start` - запуск процедуры автоматического снятия ВАХ (отправляет в терминал массив измеренных и обработанных данных)

Имена переменных:
 - `DAC_STEP` - текущий шаг регулировки ЦАП;
 - `IVC_DAC_START` - начальное значение ЦАП при автоматическом снятии ВАХ;
 - `IVC_DAC_END` - конечное значение ЦАП при автоматическом снятии ВАХ;
 - `IVC_DAC_STEP` - шаг ЦАП при автоматическом снятии ВАХ;
 - `CH0_DELTA` - калибровочное значение: смещение нуля для 0-канала АЦП [мВ];
 - `ADC_V_REF` - калибровочное значение: опорное напряжение АЦП [мВ];
 - `ACS712_KI` - калибровочное значение: коэффициент передачи датчика тока ACS712 [мВ/А].

##### Список сообщений об ошибках

1. `Split arguments failed` - ошибка разбивки строки на аргуметы;
2. `Unknown command` - неизвестная команда;
3. `Invalid argument count` - некорректное число аргументов;
4. `Invalid argument` - некорректное значение аргумента;
5. `Too many arguments` - слишком много аргументов;
6. `No arguments` - отсутствует аргумент/аргументы;
7. `Unknown error` - неизвестная ошибка;
8. `Invalid numeric parameter` - некорректное число.



## Links

1. [Зиновьев В.В., Бартенев О.А. Устройство автоматического снятия вольт-амперных характеристик фотоэлектрических преобразователей](http://f-ing.udsu.ru/files/fajly-dlya-elektronnogo-zhurnala/000572-7_2_4_19_%D0%91%D0%B0%D1%80%D1%82%D0%B5%D0%BD%D0%B5%D0%B2.pdf)