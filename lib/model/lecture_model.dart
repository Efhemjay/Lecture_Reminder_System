class Lecture {
  final String title;
  final String day;
  final String time;
  final String location;

  Lecture({
    required this.title,
    required this.day,
    required this.time,
    required this.location,
  });

  Map<String, dynamic> toJson() {
    return {'title': title, 'day': day, 'time': time, 'location': location};
  }

  factory Lecture.fromJson(Map<String, dynamic> json) {
    return Lecture(
      title: json['title'],
      day: json['day'],
      time: json['time'],
      location: json['location'],
    );
  }
}
