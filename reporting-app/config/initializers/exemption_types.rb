# frozen_string_literal: true

Rails.application.config.exemption_types = [
  care_giver: {
    question: "Are you currently a caregiver for someone with a disability or a child 13 years of age or younger?",
    explanation: "You may be eligible if you are a parent, guardian, caretaker relative, or family caregiver of a" \
      " dependent child 13 years of age or under. You may also be eligible if you care for an individual of" \
      " any age who has a disablility or who cannot care for themselves without help.",
    yes_answer: "I am a caregiver for someone who has a disability (or who is unable to care for themselves without help)" \
      " or a child under 13.",
    enabled: true
  },
  medical_condition: {
    question: "Do you have a current medical condition that makes it hard for you to work or do daily activities?",
    explanation: "You may be eligible if you have a physical, intellectual, or developmental disability, a disabling" \
      " mental disorder, or those with serious or complex medical conditions.",
    yes_answer: "I have a current medical condition that falls under one of the above categories.",
    enabled: true
  },
  substance_treatment: {
    question: "Are you currently in treatment for substance abuse?",
    explanation: "You may be eligible if you are currently in treatment for substance abuse, like drugs or alcohol. " \
      "Treatment may include counseling, group sessions, a recover program, and/or medication to help with recovery " \
      "(like methadone, suboxone, or naltrexone).",
    yes_answer: "I am currently in treatment for substance abuse.",
    enabled: true
  },
  incarceration: {
    question: "Have you been released from jail or prison in the last 90 days?",
    explanation: "You may be eligible if you have been released from incarceration in the last 90 days.",
    yes_answer: "I have been released from jail or prison in the last 90 days.",
    enabled: true
  },
  education_and_training: {
    question: "Are you a student in college or vocational training and currently enrolled at least half-time?",
    explanation: "You may be eligible if you are currently enrolled in a school at least half-time " \
      "(typicall 6 credits for undergraduate students, but may vary by institution).",
    yes_answer: "I am a student currently enrolled at least half-time.",
    enabled: true
  },
  domestic_violence: {
    question: "Are you currently experiencing or recovering from a situation where your personal safety was threatened" \
    " at home or by someone you know?",
    explanation: "You may be eligible if you are currently experiencing or recovering from a threat to your safety.",
    yes_answer: "I am currently experiencing a threat to my safety at home or by someone I know.",
    enabled: true
  },
  hospitalization: {
    question: "Have you recently stayed overnight at a medical facility or received intensive medical care?",
    explanation: "You may be eligible if you recently received intensive medical care such as: staying in a hospital overnight" \
      ", staying in a psychiatric hospital, staying in a nurshing or rehabilitation facility, or follow-up care related" \
      " to one of these stays.",
    yes_answer: "I have recently received overnight or intensive medical care.",
    enabled: true
  },
  natural_disaster: {
    question: "Do you live in a county that has a current federal disaster or emergency declaration?",
    explanation: "You may be eligible if your county has experienced a natural disaster like hurricanes, wildfires," \
      " flooding, and tornadoes or other emergencies declared by the federal government.",
    yes_answer: "My county has recently experienced a natural disaster or other federally declared emergency.",
    enabled: true
  }
]
