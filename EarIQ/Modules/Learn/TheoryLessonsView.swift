import SwiftUI

// MARK: - Model

struct TheoryLesson: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let estimatedMinutes: Int
    let sections: [LessonSection]
    let quiz: [QuizQuestion]
}

struct LessonSection: Identifiable {
    let id = UUID()
    let heading: String
    let body: String
    var audioExample: AudioExample? = nil

    struct AudioExample {
        let label: String
        let midiNotes: [UInt8]
    }
}

struct QuizQuestion: Identifiable {
    let id = UUID()
    let question: String
    let options: [String]
    let correctIndex: Int
    let explanation: String
}

// MARK: - Lesson Catalog

struct LessonCatalog {
    static let all: [TheoryLesson] = [

        TheoryLesson(id: "intervals_intro", title: "What Are Intervals?", subtitle: "The building block of melody and harmony",
                     icon: "arrow.up.right", color: .purple, estimatedMinutes: 4,
                     sections: [
                        LessonSection(heading: "Definition", body: "An interval is the distance between two pitches. Every melody and chord is built from intervals. When you hear music, you are hearing a sequence of intervals — even if you don't know their names yet."),
                        LessonSection(heading: "Half Steps & Whole Steps", body: "The smallest interval in Western music is the half step (semitone) — the distance from one piano key to the very next key, black or white. A whole step (tone) equals two half steps.\n\nFor example: C to C# is a half step. C to D is a whole step."),
                        LessonSection(heading: "Naming Intervals", body: "Intervals are named by the number of scale steps they span:\n• Unison (0 semitones)\n• Major 2nd (2 semitones)\n• Minor 3rd (3 semitones)\n• Major 3rd (4 semitones)\n• Perfect 4th (5 semitones)\n• Tritone (6 semitones)\n• Perfect 5th (7 semitones)\n• Octave (12 semitones)"),
                        LessonSection(heading: "Song Mnemonics", body: "The fastest way to recognise intervals is through familiar songs:\n• Perfect 5th → Star Wars theme\n• Perfect 4th → Here Comes the Bride\n• Major 3rd → When the Saints Go Marching In\n• Minor 3rd → Smoke on the Water (guitar riff)\n• Octave → Somewhere Over the Rainbow"),
                     ],
                     quiz: [
                        QuizQuestion(question: "How many semitones is a Perfect 5th?", options: ["5","6","7","8"], correctIndex: 2, explanation: "A Perfect 5th spans 7 semitones — the same distance as C to G."),
                        QuizQuestion(question: "Which song is a famous mnemonic for the Octave?", options: ["Jaws Theme","Star Wars","Somewhere Over the Rainbow","Happy Birthday"], correctIndex: 2, explanation: "The opening leap in 'Somewhere Over the Rainbow' is a perfect octave."),
                        QuizQuestion(question: "A whole step equals how many half steps?", options: ["1","2","3","4"], correctIndex: 1, explanation: "One whole step = two half steps (semitones)."),
                     ]),

        TheoryLesson(id: "chords_intro", title: "Understanding Chords", subtitle: "How notes stack to create harmony",
                     icon: "music.note", color: .blue, estimatedMinutes: 5,
                     sections: [
                        LessonSection(heading: "What is a Chord?", body: "A chord is three or more notes sounded simultaneously. The most common chord is the triad — built from a root, a third, and a fifth."),
                        LessonSection(heading: "Major vs Minor", body: "Major chords sound bright and happy. They use a major third (4 semitones) then a minor third (3 semitones) above the root.\n\nMinor chords sound darker or sadder. They flip the order: minor third (3 semitones) first, then major third (4 semitones)."),
                        LessonSection(heading: "Other Common Chord Types", body: "• Diminished: minor 3rd + minor 3rd (0-3-6) — very tense\n• Augmented: major 3rd + major 3rd (0-4-8) — mysterious\n• Dominant 7th: major triad + minor 7th (0-4-7-10) — blues feel\n• Major 7th: major triad + major 7th (0-4-7-11) — jazzy, lush"),
                        LessonSection(heading: "Recognising Chord Quality", body: "Train your ear to feel the emotional quality first. Major = bright. Minor = dark. Diminished = tense, unstable. Augmented = dreamy, unresolved. Once you sense the quality, naming it becomes automatic."),
                     ],
                     quiz: [
                        QuizQuestion(question: "What interval is at the core of a Major chord?", options: ["Minor 3rd","Major 3rd","Perfect 4th","Tritone"], correctIndex: 1, explanation: "A major chord is built from a major 3rd (4 semitones) above the root, then a minor 3rd above that."),
                        QuizQuestion(question: "Which word describes how Minor chords often sound?", options: ["Bright","Happy","Dark","Cheerful"], correctIndex: 2, explanation: "Minor chords typically sound darker or more melancholic than major chords."),
                        QuizQuestion(question: "A dominant 7th chord has how many notes?", options: ["2","3","4","5"], correctIndex: 2, explanation: "Dominant 7th = root + major 3rd + perfect 5th + minor 7th = 4 notes."),
                     ]),

        TheoryLesson(id: "major_scale", title: "The Major Scale", subtitle: "The foundation of Western melody",
                     icon: "waveform.path.ecg", color: .green, estimatedMinutes: 4,
                     sections: [
                        LessonSection(heading: "The Pattern", body: "The major scale follows a specific pattern of whole (W) and half (H) steps:\n\nW-W-H-W-W-W-H\n\nStarting on C: C-D-E-F-G-A-B-C\nThe intervals: 2-2-1-2-2-2-1 semitones."),
                        LessonSection(heading: "Why It Sounds Bright", body: "The major scale's pattern creates a strong sense of 'home' (the tonic). The leading tone (7th degree, just a semitone below the root) creates a powerful pull that wants to resolve upward — giving major music its sense of forward motion."),
                        LessonSection(heading: "Scale Degrees", body: "Each note in a scale has a name and function:\n• 1st (Tonic/Do) — home, very stable\n• 2nd (Supertonic/Re) — mild tension\n• 3rd (Mediant/Mi) — stable, colours the mood\n• 4th (Subdominant/Fa) — mild tension\n• 5th (Dominant/Sol) — stable, strong\n• 6th (Submediant/La) — stable, colour\n• 7th (Leading Tone/Ti) — strong tension, pulls to root"),
                        LessonSection(heading: "Relative Minor", body: "Every major scale has a relative minor — a natural minor scale that shares the same notes. Start on the 6th degree of any major scale and you get its relative natural minor. C major → A natural minor (same notes, different starting point and feel)."),
                     ],
                     quiz: [
                        QuizQuestion(question: "What is the interval pattern of a major scale?", options: ["W-H-W-W-H-W-W","W-W-H-W-W-W-H","H-W-W-W-H-W-W","W-W-W-H-W-W-H"], correctIndex: 1, explanation: "W-W-H-W-W-W-H is the defining pattern of every major scale."),
                        QuizQuestion(question: "The 7th scale degree is called the:", options: ["Dominant","Subdominant","Leading Tone","Mediant"], correctIndex: 2, explanation: "The 7th degree (Ti) is the leading tone — it creates strong tension that wants to resolve to the tonic."),
                        QuizQuestion(question: "The relative minor of C major is:", options: ["G minor","A minor","E minor","D minor"], correctIndex: 1, explanation: "A natural minor shares all the same notes as C major, starting from the 6th degree."),
                     ]),

        TheoryLesson(id: "modes", title: "Musical Modes", subtitle: "Seven flavours of the major scale",
                     icon: "dial.min.fill", color: .orange, estimatedMinutes: 6,
                     sections: [
                        LessonSection(heading: "What Are Modes?", body: "A mode is created by starting a major scale on a different degree. Every degree gives a unique flavour — same notes, different 'home base' and emotional colour."),
                        LessonSection(heading: "The Seven Modes", body: "Starting on each degree of C major:\n• Ionian (C) — the familiar major scale, bright\n• Dorian (D) — minor with a raised 6th, jazzy/soulful\n• Phrygian (E) — minor with a flat 2nd, Spanish/dark\n• Lydian (F) — major with raised 4th, dreamy/floating\n• Mixolydian (G) — major with flat 7th, rock/bluesy\n• Aeolian (A) — natural minor, melancholic\n• Locrian (B) — diminished feel, very unstable"),
                        LessonSection(heading: "How to Hear Modes", body: "Focus on the most distinctive interval from the root:\n• Lydian: the raised 4th (tritone from root) sounds 'floating'\n• Dorian: the raised 6th sounds brighter than natural minor\n• Mixolydian: the flat 7th gives a bluesy, unresolved feel\n• Phrygian: the flat 2nd (half step from root) sounds Spanish"),
                     ],
                     quiz: [
                        QuizQuestion(question: "Which mode has a raised 4th?", options: ["Dorian","Lydian","Mixolydian","Phrygian"], correctIndex: 1, explanation: "Lydian's raised 4th is its defining characteristic — creating a dreamy, floating quality."),
                        QuizQuestion(question: "Mixolydian differs from major by:", options: ["Flat 2nd","Flat 3rd","Flat 7th","Raised 4th"], correctIndex: 2, explanation: "Mixolydian = major scale with a flat 7th, giving blues and rock music its characteristic sound."),
                        QuizQuestion(question: "Which mode is the same as natural minor?", options: ["Dorian","Phrygian","Aeolian","Locrian"], correctIndex: 2, explanation: "Aeolian mode IS the natural minor scale — starting on the 6th degree of the major scale."),
                     ]),

        TheoryLesson(id: "functional_harmony", title: "Functional Harmony", subtitle: "How chords create motion and resolution",
                     icon: "ear.fill", color: Color(red:0.7,green:0.2,blue:0.9), estimatedMinutes: 6,
                     sections: [
                        LessonSection(heading: "Tonic, Dominant, Subdominant", body: "In functional harmony, every chord has a role:\n• Tonic (I) — home, stability, rest\n• Dominant (V) — tension, wants to resolve to tonic\n• Subdominant (IV) — pre-dominant, creates a sense of motion\n\nThis T-D-T and T-S-D-T motion is the engine of most Western music."),
                        LessonSection(heading: "Chord Progressions", body: "A chord progression is a sequence of chords. The most powerful progressions use dominant → tonic motion:\n\nI-IV-V-I (classic blues/rock)\nii-V-I (jazz cornerstone)\nI-V-vi-IV (modern pop)\n\nThe V chord (dominant) creates tension; landing on I releases it."),
                        LessonSection(heading: "Cadences", body: "A cadence is a harmonic ending. The four main cadences:\n• Authentic (V→I) — full stop, final resolution\n• Plagal (IV→I) — 'Amen' cadence, softer resolution\n• Half (any→V) — pause, open question\n• Deceptive (V→vi) — surprise, unexpected turn"),
                        LessonSection(heading: "Training Functional Ear", body: "The goal of functional ear training is to hear a note and know where it sits in the key — not just its name. When you can sing 'Sol' after hearing a dominant note in any key, you've developed functional pitch memory — the most powerful form of relative pitch."),
                     ],
                     quiz: [
                        QuizQuestion(question: "What is the role of the Dominant chord (V)?", options: ["Rest","Tension that wants to resolve","Colour and motion","End of a phrase"], correctIndex: 1, explanation: "The V chord creates harmonic tension that pulls strongly toward the tonic (I)."),
                        QuizQuestion(question: "ii-V-I is associated with which genre?", options: ["Classical","Blues","Jazz","Pop"], correctIndex: 2, explanation: "The ii-V-I progression is the most fundamental building block in jazz harmony."),
                        QuizQuestion(question: "A Plagal cadence uses which chord motion?", options: ["V→I","IV→I","ii→V","I→V"], correctIndex: 1, explanation: "IV→I is the Plagal cadence, sometimes called the 'Amen cadence' because of its use in hymns."),
                     ]),

        TheoryLesson(id: "rhythm_basics", title: "Rhythm Fundamentals", subtitle: "Note values, meter, and time signatures",
                     icon: "metronome.fill", color: .red, estimatedMinutes: 4,
                     sections: [
                        LessonSection(heading: "Note Values", body: "Notes have different durations:\n• Whole note = 4 beats\n• Half note = 2 beats\n• Quarter note = 1 beat (most common reference)\n• Eighth note = ½ beat\n• Sixteenth note = ¼ beat\n\nEach value is half the duration of the previous one."),
                        LessonSection(heading: "Time Signatures", body: "A time signature tells you how many beats are in each measure.\n• 4/4 — four quarter-note beats per bar (most common)\n• 3/4 — three quarter-note beats per bar (waltz feel)\n• 6/8 — six eighth-note beats per bar (compound duple — flowing feel)\n• 5/4 — five beats (asymmetric, used in jazz/prog rock)"),
                        LessonSection(heading: "Syncopation", body: "Syncopation means placing emphasis on normally unaccented beats — the 'off-beats' or 'upbeats'. In 4/4 time, beats 1 and 3 are strong; beats 2 and 4 are normally weak. Placing accents on 2 and 4 (or the 'ands') creates syncopation — the driving force behind jazz, funk, and most pop."),
                        LessonSection(heading: "Tempo and BPM", body: "Tempo is measured in BPM (beats per minute). Common tempos:\n• 60 BPM — Largo (very slow)\n• 80 BPM — Andante (walking pace)\n• 100 BPM — Moderato\n• 120 BPM — Allegro (fast)\n• 160+ BPM — Presto (very fast)"),
                     ],
                     quiz: [
                        QuizQuestion(question: "How many beats does a half note receive in 4/4 time?", options: ["1","2","3","4"], correctIndex: 1, explanation: "A half note lasts 2 beats — half of a whole note (4 beats)."),
                        QuizQuestion(question: "Syncopation emphasizes which beats in 4/4?", options: ["1 and 3","2 and 4","Only beat 1","Every beat equally"], correctIndex: 1, explanation: "Syncopation typically accents beats 2 and 4 (or off-beats), which are normally weak in 4/4."),
                        QuizQuestion(question: "What does 3/4 time mean?", options: ["3 half notes per bar","3 whole notes per bar","3 quarter notes per bar","3 eighth notes per bar"], correctIndex: 2, explanation: "3/4 means 3 quarter-note beats per measure — the time signature of a waltz."),
                     ]),
    ]
}

// MARK: - Main Lessons View

struct TheoryLessonsView: View {
    @AppStorage("completedLessons") private var completedLessonsData: Data = Data()
    @State private var selectedLesson: TheoryLesson?
    @State private var completedLessonIDs: Set<String> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    progressHeader
                    VStack(spacing: 12) {
                        ForEach(LessonCatalog.all) { lesson in
                            LessonCard(lesson: lesson,
                                       isCompleted: completedLessonIDs.contains(lesson.id)) {
                                selectedLesson = lesson
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                .padding(.bottom, 100)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Learn")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedLesson) { lesson in
                LessonDetailView(lesson: lesson) {
                    completedLessonIDs.insert(lesson.id)
                    saveCompleted()
                }
            }
            .onAppear { loadCompleted() }
        }
    }

    private var progressHeader: some View {
        let total = LessonCatalog.all.count
        let done = completedLessonIDs.count
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Theory Curriculum")
                        .font(.headline)
                    Text("\(done)/\(total) lessons completed")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(Double(done)/Double(total) * 100))%")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red:0.4,green:0.1,blue:0.9))
            }
            SwiftUI.ProgressView(value: Double(done), total: Double(total))
                .tint(Color(red:0.4,green:0.1,blue:0.9))
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }

    private func loadCompleted() {
        if let ids = try? JSONDecoder().decode(Set<String>.self, from: completedLessonsData) {
            completedLessonIDs = ids
        }
    }
    private func saveCompleted() {
        if let data = try? JSONEncoder().encode(completedLessonIDs) {
            completedLessonsData = data
        }
    }
}

// MARK: - Lesson Card

struct LessonCard: View {
    let lesson: TheoryLesson
    let isCompleted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(lesson.color.opacity(isCompleted ? 0.15 : 0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: isCompleted ? "checkmark" : lesson.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(isCompleted ? .green : lesson.color)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(lesson.title)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(isCompleted ? .secondary : .primary)
                    Text(lesson.subtitle)
                        .font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "clock").font(.caption2).foregroundStyle(.secondary)
                    Text("\(lesson.estimatedMinutes)m").font(.caption2).foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

// MARK: - Lesson Detail View

struct LessonDetailView: View {
    let lesson: TheoryLesson
    let onComplete: () -> Void

    @State private var scrollOffset: CGFloat = 0
    @State private var showQuiz = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Hero
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(lesson.color.opacity(0.15))
                                .frame(width: 60, height: 60)
                            Image(systemName: lesson.icon)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(lesson.color)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(lesson.title).font(.title3).fontWeight(.bold)
                            Label("\(lesson.estimatedMinutes) min read", systemImage: "clock")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)

                    // Sections
                    ForEach(lesson.sections) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(section.heading)
                                .font(.headline)
                            Text(section.body)
                                .font(.body)
                                .foregroundStyle(.primary.opacity(0.85))
                                .lineSpacing(4)
                            if let ex = section.audioExample {
                                AudioExampleButton(label: ex.label, midiNotes: ex.midiNotes)
                            }
                        }
                        .padding(16)
                        .background(.background, in: RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }

                    // Quiz CTA
                    if !showQuiz {
                        Button {
                            withAnimation { showQuiz = true }
                        } label: {
                            HStack {
                                Image(systemName: "questionmark.circle.fill")
                                    .foregroundStyle(lesson.color)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Take the Quiz")
                                        .font(.subheadline).fontWeight(.semibold)
                                    Text("\(lesson.quiz.count) questions • Earn XP")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(16)
                            .background(.background, in: RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(PressableButtonStyle())
                        .padding(.horizontal)
                    }

                    if showQuiz {
                        LessonQuizView(questions: lesson.quiz, lessonColor: lesson.color) {
                            onComplete()
                            dismiss()
                        }
                        .padding(.horizontal)
                    }

                    Color.clear.frame(height: 60)
                }
                .padding(.vertical)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Audio Example Button

struct AudioExampleButton: View {
    let label: String
    let midiNotes: [UInt8]
    @State private var isPlaying = false

    var body: some View {
        Button {
            guard !isPlaying else { return }
            isPlaying = true
            AudioEngine.shared.playMelody(midiNotes: midiNotes, tempo: 0.5)
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(midiNotes.count) * 0.5 + 0.5) {
                isPlaying = false
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isPlaying ? "waveform" : "speaker.wave.2.fill")
                    .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                Text(label)
                    .font(.caption).fontWeight(.medium)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Color.purple.opacity(0.12))
            .foregroundStyle(Color.purple)
            .clipShape(Capsule())
        }
    }
}

// MARK: - Quiz View

struct LessonQuizView: View {
    let questions: [QuizQuestion]
    let lessonColor: Color
    let onFinish: () -> Void

    @State private var currentIndex = 0
    @State private var selectedAnswer: Int?
    @State private var score = 0
    @State private var isComplete = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isComplete {
                quizComplete
            } else {
                let q = questions[currentIndex]
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Question \(currentIndex + 1) of \(questions.count)")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        SwiftUI.ProgressView(value: Double(currentIndex), total: Double(questions.count))
                            .tint(lessonColor)
                            .frame(width: 80)
                    }
                    Text(q.question)
                        .font(.headline)

                    ForEach(q.options.indices, id: \.self) { i in
                        QuizOptionButton(
                            text: q.options[i],
                            state: optionState(q: q, i: i),
                            isEnabled: selectedAnswer == nil
                        ) { selectOption(q: q, i: i) }
                    }

                    if let sel = selectedAnswer {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: sel == q.correctIndex ? "checkmark.circle.fill" : "lightbulb.fill")
                                    .foregroundStyle(sel == q.correctIndex ? .green : .orange)
                                Text(q.explanation)
                                    .font(.caption)
                            }
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        .transition(.move(edge: .bottom).combined(with: .opacity))

                        Button(currentIndex + 1 < questions.count ? "Next" : "Finish") {
                            advanceOrFinish()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(lessonColor)
                        .foregroundStyle(.white)
                        .fontWeight(.semibold)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .buttonStyle(PressableButtonStyle())
                    }
                }
                .padding(16)
                .background(.background, in: RoundedRectangle(cornerRadius: 16))
                .animation(.spring(response: 0.3), value: selectedAnswer)
            }
        }
    }

    private var quizComplete: some View {
        VStack(spacing: 14) {
            Image(systemName: score == questions.count ? "star.fill" : "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundStyle(score == questions.count ? .yellow : lessonColor)
            Text(score == questions.count ? "Perfect Score!" : "Lesson Complete!")
                .font(.headline)
            Text("\(score)/\(questions.count) correct • +\(score * 25) XP earned")
                .font(.subheadline).foregroundStyle(.secondary)
            Button("Continue") { onFinish() }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(lessonColor)
                .foregroundStyle(.white)
                .fontWeight(.semibold)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .buttonStyle(PressableButtonStyle())
        }
        .padding(20)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private func optionState(q: QuizQuestion, i: Int) -> AnswerButtonState {
        guard let sel = selectedAnswer else { return .idle }
        if i == q.correctIndex { return .correct }
        if i == sel { return .wrong }
        return .dimmed
    }

    private func selectOption(q: QuizQuestion, i: Int) {
        guard selectedAnswer == nil else { return }
        selectedAnswer = i
        if i == q.correctIndex { score += 1 }
        i == q.correctIndex ? HapticsManager.success() : HapticsManager.error()
    }

    private func advanceOrFinish() {
        if currentIndex + 1 < questions.count {
            currentIndex += 1
            selectedAnswer = nil
        } else {
            withAnimation { isComplete = true }
        }
    }
}

struct QuizOptionButton: View {
    let text: String
    let state: AnswerButtonState
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(text).font(.subheadline).foregroundStyle(foreground)
                Spacer()
                if state == .correct { Image(systemName: "checkmark.circle.fill").foregroundStyle(.green) }
                if state == .wrong   { Image(systemName: "xmark.circle.fill").foregroundStyle(.red) }
            }
            .padding(12)
            .background(background, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(border, lineWidth: 1))
        }
        .disabled(!isEnabled)
        .buttonStyle(PressableButtonStyle())
        .animation(.spring(response: 0.2), value: state)
    }

    private var background: Color {
        switch state {
        case .idle: return Color(.systemBackground)
        case .correct: return Color.green.opacity(0.12)
        case .wrong: return Color.red.opacity(0.12)
        case .dimmed: return Color(.systemBackground).opacity(0.6)
        }
    }
    private var border: Color { state == .idle ? Color(.separator) : .clear }
    private var foreground: Color {
        switch state { case .correct: return .green; case .wrong: return .red; case .dimmed: return .secondary; default: return .primary }
    }
}
