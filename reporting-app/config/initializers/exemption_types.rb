# frozen_string_literal: true

Rails.application.config.exemption_types = [
  {
    id: :caregiver_disability,
    title: "Caregiver of Person with Disability or Incapable of Self-Care",
    description: "Individual who provides daily care to someone with a disability or who cannot care for themselves (child or adult).",
    supporting_documents: [
      "Provider attestation or care plan indicating caregiver role",
      "Documentation of dependent’s disability (e.g., SSA award, IEP, long-term care status)",
      "Power of attorney, guardianship, or service authorization forms"
    ],
    question: "Are you currently a caregiver for someone with a disability or someone who cannot care for themselves without help?",
    explanation: "You may be eligible for an exemption if you care for an individual of any age who has a disability or who cannot" \
      " care for themselves without help.",
    yes_answer: "I am a caregiver for someone who has a disability or who is unable to care for themselves without help.",
    enabled: true
  },
  {
    id: :caregiver_child,
    title: "Parent or Caregiver of Dependent Age 13 or Younger",
    description: "Parent or legal guardian of a young child (≤13), living in the same household.",
    supporting_documents: [
      "Relationship and co-residence verified via Medicaid/SNAP case",
      "Child's birth certificate or custody paperwork",
      "TANF or SNAP eligibility file indicating dependent child"
    ],
    question: "Are you currently a caregiver for a child 13 years of age or under?",
    explanation: "You may be eligible for an exemption if you are a parent, guardian, caretaker relative, " \
      "or family caregiver of a dependent child 13 years of age and under. ",
    yes_answer: "I am a caregiver for a child under 13.",
    enabled: true
  },
  {
    id: :medical_condition,
    title: "Medically Frail or Special Medical Needs",
    description: "Individual with serious, chronic, or disabling physical/mental health conditions.",
    supporting_documents: [
      "Disability determination (SSA or Medicaid)",
      "Physician attestation or diagnostic report",
      "Enrollment in long-term services and supports (LTSS), SUD treatment, or home- and community-based services",
      "MMIS data showing chronic or complex conditions"
    ],
    question: "Do you have a current medical condition that makes it hard for you to work or do daily activities?",
    explanation: "You may be eligible if you have a physical, intellectual, or developmental disability, a disabling" \
      " mental disorder, or those with serious or complex medical conditions.",
    yes_answer: "I have a current medical condition that falls under one of the above categories.",
    enabled: true
  },
  {
    id: :substance_treatment,
    title: "Medically Frail or Special Medical Needs",
    description: "Individual with serious, chronic, or disabling physical/mental health conditions.",
    supporting_documents: [
      "Disability determination (SSA or Medicaid)",
      "Physician attestation or diagnostic report",
      "Enrollment in long-term services and supports (LTSS), SUD treatment, or home- and community-based services",
      "MMIS data showing chronic or complex conditions"
    ],
    question: "Are you currently in treatment for substance abuse?",
    explanation: "You may be eligible if you are currently in treatment for substance abuse, like drugs or alcohol. " \
      "Treatment may include counseling, group sessions, a recover program, and/or medication to help with recovery " \
      "(like methadone, suboxone, or naltrexone).",
    yes_answer: "I am currently in treatment for substance abuse.",
    enabled: true
  },
  {
    id: :incarceration,
    title: "Recently Released from Incarceration (within 90 days)",
    description: "Released from jail or prison within the past three months.",
    supporting_documents: [
      "Release documentation from correctional facility",
      "Probation or parole status record",
      "Reentry program enrollment documents"
    ],
    question: "Have you been released from jail or prison in the last 90 days?",
    explanation: "You may be eligible if you have been released from incarceration in the last 90 days.",
    yes_answer: "I have been released from jail or prison in the last 90 days.",
    enabled: true
  },
  {
    id: :education_and_training,
    title: "Student Enrolled at Least Half-Time",
    description: "Actively enrolled in education or job training for at least half of a full-time course load.",
    supporting_documents: [
      "Transcript or course schedule showing at least half-time enrollment (typically 6+ credit hours)",
      "Enrollment verification letter from institution",
      "FAFSA or Pell Grant records"
    ],
    question: "Are you a student in college or vocational training and currently enrolled at least half-time?",
    explanation: "You may be eligible if you are currently enrolled in a school at least half-time " \
      "(typicall 6 credits for undergraduate students, but may vary by institution).",
    yes_answer: "I am a student currently enrolled at least half-time.",
    enabled: true
  },
  {
    id: :received_medical_care,
    title: "Received High-Acuity Medical Care",
    description: "Hospitalization or intensive treatment that made work impossible during the month.",
    supporting_documents: [
      "Hospital discharge summary",
      "Inpatient admission records",
      "Provider statement confirming high-acuity care"
    ],
    question: "Have you recently stayed overnight at a medical facility or received intensive medical care?",
    explanation: "You may be eligible if you recently received intensive medical care such as: staying in a hospital overnight" \
      ", staying in a psychiatric hospital, staying in a nurshing or rehabilitation facility, or follow-up care related" \
      " to one of these stays.",
    yes_answer: "I have recently received overnight or intensive medical care.",
    enabled: true
  }
  # TODO: Add federal disaster declaration and medical care travel
]
