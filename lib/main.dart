import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:fl_chart/fl_chart.dart';

const _native = MethodChannel('planner/alarm');
final _db = PlannerDb();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _db.open();
  runApp(const PlannerApp());
}

class PlannerDb {
  Database? _database;
  Future<void> open() async {
    final base = await getDatabasesPath();
    _database = await openDatabase(p.join(base, 'planner_permanent.db'), version: 1,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE tasks(id INTEGER PRIMARY KEY AUTOINCREMENT, day TEXT NOT NULL, slot TEXT NOT NULL, title TEXT NOT NULL, done INTEGER NOT NULL DEFAULT 0, UNIQUE(day,slot))');
        await db.execute('CREATE TABLE completed(id INTEGER PRIMARY KEY AUTOINCREMENT, day TEXT NOT NULL, title TEXT NOT NULL, minutes INTEGER NOT NULL, source TEXT NOT NULL, task_id INTEGER, created_at INTEGER NOT NULL)');
      });
  }
  Database get db => _database!;
  Future<List<Map<String,Object?>>> tasks(String day) => db.query('tasks', where:'day=?', whereArgs:[day], orderBy:'slot');
  Future<void> putTask(String day,String slot,String title) async {
    final rows = await db.query('tasks', where: 'day=? AND slot=?', whereArgs: [day, slot], limit: 1);
    if (rows.isEmpty) {
      await db.insert('tasks', {'day': day, 'slot': slot, 'title': title, 'done': 0});
    } else {
      final id = rows.first['id'] as int;
      await db.update('tasks', {'title': title}, where: 'id=?', whereArgs: [id]);
      await db.update('completed', {'title': title}, where: 'task_id=?', whereArgs: [id]);
    }
  }
  Future<void> toggleTask(int id,bool done) async {
    await db.update('tasks', {'done':done?1:0}, where:'id=?', whereArgs:[id]);
    if(done) {
      final rows=await db.query('tasks',where:'id=?',whereArgs:[id]);
      if(rows.isNotEmpty) {
        final r=rows.first;
        await addCompleted(r['day'] as String,r['title'] as String,0,'task',taskId:id);
      }
    } else {
      final rows=await db.query('tasks',where:'id=?',whereArgs:[id]);
      if(rows.isNotEmpty) await db.delete('completed',where:'task_id=?',whereArgs:[id]);
    }
  }
  Future<void> addCompleted(String day,String title,int minutes,String source,{int? taskId}) async { await db.insert('completed', {'day':day,'title':title,'minutes':minutes,'source':source,'task_id':taskId,'created_at':DateTime.now().millisecondsSinceEpoch}); }
  Future<List<Map<String,Object?>>> completed(String day) => db.query('completed',where:'day=?',whereArgs:[day],orderBy:'created_at DESC');
  Future<void> deleteCompleted(int id) async { await db.delete('completed',where:'id=?',whereArgs:[id]); }
  Future<int> total(String day) async { final r=await db.rawQuery('SELECT COALESCE(SUM(minutes),0) n FROM completed WHERE day=?',[day]); return (r.first['n'] as int?)??0; }
  Future<int> doneCount(String day) async { final r=await db.rawQuery('SELECT COUNT(*) n FROM tasks WHERE day=? AND done=1',[day]); return (r.first['n'] as int?)??0; }
  Future<int> taskCount(String day) async { final r=await db.rawQuery('SELECT COUNT(*) n FROM tasks WHERE day=? AND title<>""',[day]); return (r.first['n'] as int?)??0; }
}

String keyOf(DateTime d) => '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
DateTime dayOnly(DateTime d)=>DateTime(d.year,d.month,d.day);
String fa(String s)=>s.replaceAll('0','۰').replaceAll('1','۱').replaceAll('2','۲').replaceAll('3','۳').replaceAll('4','۴').replaceAll('5','۵').replaceAll('6','۶').replaceAll('7','۷').replaceAll('8','۸').replaceAll('9','۹');
String jalali(DateTime d) {
  final j = Jalali.fromDateTime(d);
  const months = [
    'فروردین', 'اردیبهشت', 'خرداد', 'تیر',
    'مرداد', 'شهریور', 'مهر', 'آبان',
    'آذر', 'دی', 'بهمن', 'اسفند'
  ];

  return '${fa(j.day.toString())} ${months[j.month - 1]} ${fa(j.year.toString())}';
}

String jalaliMonth(DateTime d) {
  final j = Jalali.fromDateTime(d);
  const months = [
    'فروردین', 'اردیبهشت', 'خرداد', 'تیر',
    'مرداد', 'شهریور', 'مهر', 'آبان',
    'آذر', 'دی', 'بهمن', 'اسفند'
  ];

  return '${months[j.month - 1]} ${fa(j.year.toString())}';
}
String durationText(int m)=>m>=60?'${fa((m~/60).toString())} ساعت${m%60>0?' و ${fa((m%60).toString())} دقیقه':''}':'${fa(m.toString())} دقیقه';
const weekdays=['شنبه','یکشنبه','دوشنبه','سه‌شنبه','چهارشنبه','پنجشنبه','جمعه'];

class PlannerApp extends StatefulWidget { const PlannerApp({super.key}); @override State<PlannerApp> createState()=>_PlannerAppState(); }
class _PlannerAppState extends State<PlannerApp>{ ThemeMode mode=ThemeMode.light; @override void initState(){super.initState();_load();} Future<void> _load()async{final p=await SharedPreferences.getInstance();setState(()=>mode=p.getBool('dark')==true?ThemeMode.dark:ThemeMode.light);} Future<void> setMode(bool dark)async{final p=await SharedPreferences.getInstance();await p.setBool('dark',dark);setState(()=>mode=dark?ThemeMode.dark:ThemeMode.light);}
 @override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false,title:'برنامه‌ریز من',locale:const Locale('fa'),supportedLocales:const [Locale('fa')],localizationsDelegates:const [GlobalMaterialLocalizations.delegate,GlobalWidgetsLocalizations.delegate,GlobalCupertinoLocalizations.delegate],themeMode:mode,theme:ThemeData(useMaterial3:true,colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xff0f766e)),scaffoldBackgroundColor:const Color(0xfff1f4f6),fontFamily:'sans-serif'),darkTheme:ThemeData(useMaterial3:true,brightness:Brightness.dark,colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xff42b8a8),brightness:Brightness.dark),fontFamily:'sans-serif'),home:Home(onTheme:setMode,dark:mode==ThemeMode.dark)); }

class Home extends StatefulWidget{final Future<void> Function(bool) onTheme;final bool dark;const Home({super.key,required this.onTheme,required this.dark});@override State<Home> createState()=>_HomeState();}
class _HomeState extends State<Home>{int tab=0;DateTime selected=dayOnly(DateTime.now());int focus=25,shortBreak=5,longBreak=15,every=4;String pmMode='focus',label='';int left=1500,cycles=0;bool running=false;DateTime? endAt;Timer? ticker;final manualName=TextEditingController(),manualMin=TextEditingController();final taskControllers=<String,TextEditingController>{};
 @override void initState(){super.initState();_loadSettings();ticker=Timer.periodic(const Duration(seconds:1),(_){if(running&&endAt!=null){final n=endAt!.difference(DateTime.now()).inSeconds;if(n<=0){_finish();}else if(mounted)setState(()=>left=n);}});}
 Future<void> _loadSettings()async{final p=await SharedPreferences.getInstance();if(!mounted)return;setState((){focus=p.getInt('focus')??25;shortBreak=p.getInt('short')??5;longBreak=p.getInt('long')??15;every=p.getInt('every')??4;cycles=p.getInt('cycles')??0;left=focus*60;final end=p.getInt('timer_end');if(p.getBool('timer_running')==true&&end!=null&&end>DateTime.now().millisecondsSinceEpoch){pmMode=p.getString('timer_mode')??'focus';label=p.getString('timer_label')??'';endAt=DateTime.fromMillisecondsSinceEpoch(end);left=((end-DateTime.now().millisecondsSinceEpoch)/1000).ceil();running=true;}});}
 @override void dispose(){ticker?.cancel();manualName.dispose();manualMin.dispose();for(final c in taskControllers.values){c.dispose();}super.dispose();}
 Future<void> _saveSettings()async{final p=await SharedPreferences.getInstance();await p.setInt('focus',focus);await p.setInt('short',shortBreak);await p.setInt('long',longBreak);await p.setInt('every',every);}
 Future<void> _scheduleNative(int seconds)async{try{await _native.invokeMethod('scheduleFocusAlarm',{'delayMs':seconds*1000,'title':label.isEmpty?'پایان زمان تمرکز':'پایان تمرکز: $label'});}catch(_){} }
 Future<void> _cancelNative()async{try{await _native.invokeMethod('cancelFocusAlarm');}catch(_){} }
 void _startPause()async{final prefs=await SharedPreferences.getInstance();if(running){running=false;endAt=null;await _cancelNative();await prefs.remove('timer_end');await prefs.setBool('timer_running',false);}else{running=true;endAt=DateTime.now().add(Duration(seconds:left));await prefs.setInt('timer_end',endAt!.millisecondsSinceEpoch);await prefs.setBool('timer_running',true);await prefs.setString('timer_mode',pmMode);await prefs.setString('timer_label',label);if(pmMode=='focus')await _scheduleNative(left);}setState((){});}
 void _finish()async{running=false;endAt=null;final prefs=await SharedPreferences.getInstance();await prefs.setBool('timer_running',false);await prefs.remove('timer_end');if(pmMode=='focus'){cycles++;await prefs.setInt('cycles',cycles);await _db.addCompleted(keyOf(DateTime.now()),label.isEmpty?'پومودورو':label,focus,'pomodoro');pmMode=cycles%every==0?'long':'short';}else{pmMode='focus';}left=(pmMode=='focus'?focus:pmMode=='short'?shortBreak:longBreak)*60;if(mounted){setState((){});if(pmMode!='focus')_snack('دوره تمرکز به پایان رسید');}}
 void _reset()async{running=false;endAt=null;await _cancelNative();final prefs=await SharedPreferences.getInstance();await prefs.setBool('timer_running',false);await prefs.remove('timer_end');setState(()=>left=(pmMode=='focus'?focus:pmMode=='short'?shortBreak:longBreak)*60);}
 void _skip()async{running=false;endAt=null;_cancelNative();final prefs=await SharedPreferences.getInstance();await prefs.setBool('timer_running',false);await prefs.remove('timer_end');setState((){pmMode=pmMode=='focus'?'short':'focus';left=(pmMode=='focus'?focus:shortBreak)*60;});}
 void _snack(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
 Future<void> _manualAdd()async{final name=manualName.text.trim();final m=int.tryParse(manualMin.text);if(name.isEmpty||m==null||m<1){_snack('نام فعالیت و زمان معتبر را وارد کنید');return;}await _db.addCompleted(keyOf(selected),name,m,'manual');manualName.clear();manualMin.clear();setState((){});}
 Future<void> _changeDay(int n)async{setState(()=>selected=selected.add(Duration(days:n)));}
 @override Widget build(BuildContext context){return Scaffold(appBar:AppBar(title:const Text('برنامه‌ریز من',style:TextStyle(fontWeight:FontWeight.bold)),actions:[IconButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>SettingsPage(dark:widget.dark,onTheme:widget.onTheme,focus:focus,shortBreak:shortBreak,longBreak:longBreak,every:every,onSave:(f,s,l,e){setState((){focus=f;shortBreak=s;longBreak=l;every=e;if(!running)left=focus*60;});_saveSettings();}))),icon:const Icon(Icons.settings_outlined))]),body:IndexedStack(index:tab,children:[_dayView(),_weekView(),_monthView()]),bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const [NavigationDestination(icon:Icon(Icons.today_outlined),label:'روزانه'),NavigationDestination(icon:Icon(Icons.view_week_outlined),label:'هفتگی'),NavigationDestination(icon:Icon(Icons.calendar_month_outlined),label:'ماهانه')]),);}
 Widget _panel(Widget child)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:child));
 Widget _dayView()=>ListView(padding:const EdgeInsets.all(12),children:[_timerCard(),_panel(Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[IconButton(onPressed:()=>_changeDay(-1),icon:const Icon(Icons.chevron_right)),Expanded(child:Column(children:[Text(jalali(selected),style:Theme.of(context).textTheme.titleMedium),Text(keyOf(selected),style:Theme.of(context).textTheme.bodySmall)])),IconButton(onPressed:()=>setState(()=>selected=dayOnly(DateTime.now())),icon:const Icon(Icons.today)),IconButton(onPressed:()=>_changeDay(1),icon:const Icon(Icons.chevron_left))]),FutureBuilder<List<Map<String,Object?>>>(future:_db.tasks(keyOf(selected)),builder:(c,s){final rows=s.data??[];return Column(children:List.generate(36,(i){final slot='${(6+i~/2).toString().padLeft(2,'0')}:${i.isOdd?'30':'00'}';final matches=rows.where((r)=>r['slot']==slot);final row=matches.isEmpty?null:matches.first;final ctrlKey='${keyOf(selected)}|$slot';final ctrl=taskControllers.putIfAbsent(ctrlKey,()=>TextEditingController(text:row?['title'] as String? ??''));if(row!=null&&ctrl.text!=(row['title'] as String))ctrl.text=row['title'] as String;final checked=row?['done']==1;return Padding(padding:const EdgeInsets.symmetric(vertical:2),child:Row(children:[SizedBox(width:52,child:Text(fa(slot),style:Theme.of(context).textTheme.bodySmall)),Checkbox(value:checked??false,onChanged:row==null?null:(v)async{await _db.toggleTask(row['id'] as int,v??false);setState((){});}),Expanded(child:TextField(controller:ctrl,decoration:const InputDecoration(hintText:'کاری تعریف کنید...',isDense:true,border:InputBorder.none),onSubmitted:(v)async{if(v.trim().isNotEmpty)await _db.putTask(keyOf(selected),slot,v.trim());setState((){});},onChanged:(v){_db.putTask(keyOf(selected),slot,v); })),if(row!=null&&ctrl.text.trim().isNotEmpty)IconButton(tooltip:'تمرکز روی این کار',onPressed:(){label=ctrl.text;setState((){});},icon:const Icon(Icons.play_circle_outline,size:20))]));}));}),const Divider(),_manualEntry(),const SizedBox(height:8),_completedPanel()]))]);
 Widget _manualEntry()=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('ثبت فعالیت و زمان صرف‌شده',style:TextStyle(fontWeight:FontWeight.bold)),const SizedBox(height:8),Row(children:[Expanded(flex:3,child:TextField(controller:manualName,decoration:const InputDecoration(hintText:'نام فعالیت',border:OutlineInputBorder(),isDense:true))),const SizedBox(width:8),Expanded(child:TextField(controller:manualMin,keyboardType:TextInputType.number,decoration:const InputDecoration(hintText:'دقیقه',border:OutlineInputBorder(),isDense:true))),const SizedBox(width:8),FilledButton(onPressed:_manualAdd,child:const Text('ثبت'))])]);
 Widget _completedPanel()=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('فعالیت‌های انجام‌شده',style:TextStyle(fontWeight:FontWeight.bold)),FutureBuilder<List<Map<String,Object?>>>(future:_db.completed(keyOf(selected)),builder:(c,s){final rows=s.data??[];final total=rows.fold<int>(0,(a,r)=>a+(r['minutes'] as int));return Column(children:[if(rows.isEmpty)const Padding(padding:EdgeInsets.all(12),child:Text('هنوز فعالیتی ثبت نشده است.')),...rows.map((r)=>ListTile(contentPadding:EdgeInsets.zero,dense:true,leading:const Icon(Icons.check_circle_outline,color:Colors.teal),title:Text(r['title'] as String),trailing:Row(mainAxisSize:MainAxisSize.min,children:[Text(r['source']=='task'?'تسک انجام‌شده':(r['minutes'] as int)==0?'پومودورو':durationText(r['minutes'] as int)),IconButton(onPressed:()async{await _db.deleteCompleted(r['id'] as int);setState((){});},icon:const Icon(Icons.close,size:18))]))),if(rows.isNotEmpty)Align(alignment:Alignment.centerLeft,child:Text('مجموع زمان ثبت‌شده: ${durationText(total)}',style:const TextStyle(fontWeight:FontWeight.bold))) ]);})]);
 Widget _timerCard(){final m=(left~/60).toString().padLeft(2,'0'),s=(left%60).toString().padLeft(2,'0');final mode=pmMode=='focus'?'تمرکز':pmMode=='short'?'استراحت کوتاه':'استراحت بلند';return _panel(Column(children:[Text('پومودورو',style:Theme.of(context).textTheme.titleMedium),Text(mode,style:TextStyle(color:pmMode=='focus'?Colors.teal:Colors.blue,fontWeight:FontWeight.bold)),Text('$m:$s',style:const TextStyle(fontSize:48,fontWeight:FontWeight.bold,letterSpacing:2)),Text(label.isEmpty?'دوره‌های کامل: ${fa(cycles.toString())}':'روی: $label',style:Theme.of(context).textTheme.bodySmall),Row(mainAxisAlignment:MainAxisAlignment.center,children:[FilledButton(onPressed:_startPause,child:Text(running?'توقف':'شروع')),const SizedBox(width:8),OutlinedButton(onPressed:_skip,child:const Text('رد کردن')),const SizedBox(width:8),OutlinedButton(onPressed:_reset,child:const Text('از نو'))]) ]));}
 DateTime _weekStart(DateTime d)=>dayOnly(d).subtract(Duration(days:d.weekday%7+1==7?0:d.weekday%7+1));
 Widget _weekView() {
  final start = dayOnly(selected).subtract(Duration(days: (selected.weekday + 1) % 7));
  final days = List.generate(7, (i) => start.add(Duration(days: i)));
  return FutureBuilder<List<int>>(
    future: Future.wait(days.map((d) => _db.total(keyOf(d)))),
    builder: (context, snapshot) {
      final vals = snapshot.data ?? List.filled(7, 0);
      final total = vals.fold<int>(0, (a, b) => a + b);
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _panel(Column(children: [
            Row(children: [
              IconButton(onPressed: () => _changeDay(-7), icon: const Icon(Icons.chevron_right)),
              const Expanded(child: Text('گزارش هفتگی', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
              IconButton(onPressed: () => _changeDay(7), icon: const Icon(Icons.chevron_left)),
            ]),
            Text('${jalali(start)} تا ${jalali(days.last)}'),
            const SizedBox(height: 12),
            Text('مجموع زمان ثبت‌شده: ${durationText(total)}'),
            SizedBox(
              height: 190,
              child: BarChart(BarChartData(
                alignment: BarChartAlignment.spaceAround,
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt().clamp(0, 6).toInt();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(weekdays[index].substring(0, 1), style: const TextStyle(fontSize: 11)),
                      );
                    },
                  )),
                ),
                barGroups: List.generate(7, (i) => BarChartGroupData(
                  x: i,
                  barRods: [BarChartRodData(
                    toY: vals[i].toDouble(),
                    width: 14,
                    borderRadius: BorderRadius.circular(4),
                    color: Theme.of(context).colorScheme.primary,
                  )],
                )),
              )),
            ),
            ...List.generate(7, (i) => ListTile(
              title: Text('${weekdays[i]} ${jalali(days[i])}'),
              subtitle: Text(durationText(vals[i])),
              onTap: () => setState(() => selected = days[i]),
            )),
          ])),
        ],
      );
    },
  );
 }

 Widget _monthView() {
  final j = Jalali.fromDateTime(selected);
  final first = Jalali(j.year, j.month, 1).toDateTime();
  final count = j.monthLength;
  final offset = (first.weekday + 1) % 7;
  return FutureBuilder<List<int>>(
    future: Future.wait(List.generate(count, (i) => _db.total(keyOf(DateTime(first.year, first.month, first.day + i))))),
    builder: (context, snapshot) {
      final vals = snapshot.data ?? List.filled(count, 0);
      final total = vals.fold<int>(0, (a, b) => a + b);
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _panel(Column(children: [
            Row(children: [
              IconButton(
                onPressed: () => setState(() => selected = (j.month == 1 ? Jalali(j.year - 1, 12, 1) : Jalali(j.year, j.month - 1, 1)).toDateTime()),
                icon: const Icon(Icons.chevron_right),
              ),
              Expanded(child: Text(jalaliMonth(selected), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold))),
              IconButton(
                onPressed: () => setState(() => selected = (j.month == 12 ? Jalali(j.year + 1, 1, 1) : Jalali(j.year, j.month + 1, 1)).toDateTime()),
                icon: const Icon(Icons.chevron_left),
              ),
            ]),
            Text('مجموع فعالیت ثبت‌شده: ${durationText(total)}'),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                ...weekdays.map((d) => Center(child: Text(d.substring(0, 1), style: Theme.of(context).textTheme.bodySmall))),
                ...List.generate(offset, (_) => const SizedBox()),
                ...List.generate(count, (i) {
                  final day = DateTime(first.year, first.month, i + 1);
                  return InkWell(
                    onTap: () => setState(() => selected = day),
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: vals[i] > 0 ? Theme.of(context).colorScheme.primary.withOpacity(.16) : null,
                        border: Border.all(color: dayOnly(day) == selected ? Theme.of(context).colorScheme.primary : Colors.transparent, width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(fa('${i + 1}'), style: const TextStyle(fontWeight: FontWeight.bold)),
                        if (vals[i] > 0) Text('${fa((vals[i] / 60).toStringAsFixed(1))}س', style: const TextStyle(fontSize: 9)),
                      ]),
                    ),
                  );
                }),
              ],
            ),
          ])),
        ],
      );
    },
  );
 }
}

class SettingsPage extends StatefulWidget{final bool dark;final Future<void> Function(bool) onTheme;final int focus,shortBreak,longBreak,every;final void Function(int,int,int,int) onSave;const SettingsPage({super.key,required this.dark,required this.onTheme,required this.focus,required this.shortBreak,required this.longBreak,required this.every,required this.onSave});@override State<SettingsPage> createState()=>_SettingsPageState();}
class _SettingsPageState extends State<SettingsPage>{late int f,s,l,e;@override void initState(){super.initState();f=widget.focus;s=widget.shortBreak;l=widget.longBreak;e=widget.every;}Widget field(String title,int value,ValueChanged<int> change)=>Padding(padding:const EdgeInsets.symmetric(vertical:6),child:TextField(key:ValueKey(title),controller:TextEditingController(text:'$value'),keyboardType:TextInputType.number,decoration:InputDecoration(labelText:title,border:const OutlineInputBorder()),onChanged:(v)=>change(int.tryParse(v)??value)));@override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('تنظیمات')),body:ListView(padding:const EdgeInsets.all(16),children:[SwitchListTile(title:const Text('تم تاریک'),value:widget.dark,onChanged:widget.onTheme),const Divider(),const Text('تنظیمات پومودورو',style:TextStyle(fontWeight:FontWeight.bold)),field('مدت تمرکز (دقیقه)',f,(v)=>f=v),field('استراحت کوتاه (دقیقه)',s,(v)=>s=v),field('استراحت بلند (دقیقه)',l,(v)=>l=v),field('استراحت بلند بعد از چند دوره',e,(v)=>e=v),const SizedBox(height:12),FilledButton(onPressed:(){widget.onSave(f.clamp(1,240).toInt(),s.clamp(1,120).toInt(),l.clamp(1,180).toInt(),e.clamp(2,12).toInt());Navigator.pop(context);},child:const Text('ذخیره تنظیمات')),const SizedBox(height:12),const Text('اطلاعات برنامه در پایگاه داده محلی گوشی ذخیره می‌شود و برای ثبت فعالیت‌ها به اینترنت نیاز نیست.',style:TextStyle(color:Colors.grey))]));}
