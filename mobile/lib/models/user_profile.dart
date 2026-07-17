class UserProfile {
  String sex = '男';
  DateTime birthday = DateTime(1995, 7, 12);
  int heightCm = 175;
  int weightKg = 70;
  String experience = '练过一阵';
  String limitation = '暂无';
  String? spokenIntroduction;

  int ageAt(DateTime date) {
    var age = date.year - birthday.year;
    if (date.month < birthday.month ||
        (date.month == birthday.month && date.day < birthday.day)) {
      age--;
    }
    return age;
  }
}
