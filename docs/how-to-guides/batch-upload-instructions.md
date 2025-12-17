# Batch Upload Instruction Guide

## Overview

The Batch Upload feature allows staff members to upload and process multiple certifications at once using CSV files. This guide walks through how to prepare your data, upload a batch file, and view results.

## Prerequisites

- **Admin access** to the Medicaid staff portal
- A properly formatted **CSV file** (see Data Schema below)

---

## Data Schema

### Required Fields

| Field | Description | Format |
|-------|-------------|--------|
| `member_id` | Unique member identifier | Text (e.g., M12345) |
| `case_number` | Medicaid case number (must be unique) | Text (e.g., C-001) |
| `member_email` | Member's email address | Valid email |
| `certification_date` | Date of certification | YYYY-MM-DD |
| `certification_type` | Type of certification | `new_application` or `recertification` |

### Optional Fields

| Field | Description | Format |
|-------|-------------|--------|
| `first_name` | Member's first name | Text |
| `middle_name` | Member's middle name | Text |
| `last_name` | Member's last name | Text |
| `lookback_period` | Months to look back | Integer |
| `number_of_months_to_certify` | Months to certify | Integer |
| `due_period_days` | Days until due | Integer |
| `address` | Street address | Text |
| `county` | County name | Text |
| `zip_code` | ZIP code | Text (e.g., 12345) |
| `date_of_birth` | Date of birth | YYYY-MM-DD |
| `pregnancy_status` | Pregnancy status | `yes` or `no` |
| `race_ethnicity` | Race/ethnicity | Text |
| `work_hours` | Current work hours | Integer |
| `other_income_sources` | Other income description | Text |

### Example CSV

[Download sample CSV file](/docs/assets/test_data.csv)  
Note: If you want to receive an email notification, change the emails in the test_data.csv to real emails. 

```csv
member_id,case_number,member_email,first_name,last_name,certification_date,certification_type,date_of_birth,pregnancy_status,race_ethnicity
M12345,C-001,john.doe@example.com,John,Doe,2025-01-15,new_application,1990-05-15,no,white
M12346,C-002,jane.smith@example.com,Jane,Smith,2025-01-15,recertification,1985-03-20,yes,black
```

---

## Step 1: Prepare Your CSV File

1. Create a CSV file with the required columns (see Data Schema above). You can also [download the sample CSV file](/docs/assets/test_data.csv) 
2. Ensure **case numbers are unique** — duplicate case numbers will cause upload errors
3. Save the file as `.csv` format

### Testing Exemptions

To test different exemption scenarios, use the following fields:

| Exemption Type | How to Test |
|----------------|-------------|
| **Age exemption** | Set `date_of_birth` so member is under 19 or over 64 |
| **Tribal exemption** | Set `race_ethnicity` to `american_indian_or_alaska_native` |
| **Pregnancy exemption** | Set `pregnancy_status` to `yes` |

**Note:** For Medicaid age eligibility, members must be between 19 and 64 years old.

---

## Step 2: Upload Your CSV File

1. Navigate to **Batch Uploads** in the header navigation (or go directly to `/staff/certification_batch_uploads`)
2. Click **"Upload New File"**  

<img src="/docs/assets/Certification_Batch_Uploads_Main_Page.png" width="100%" alt="Batch Uploads" />


3. Select your CSV file
<img src="/docs/assets/Upload_Certification_Roster_Page_CSV_Format_Requirements.png" width="100%" alt="Upload Certification Roster Format Requirements" />
<img src="/docs/assets/Upload_Certification_Roster_Upload_Process.png" width="100%" alt="Upload Certification Roster Upload" />

5. Click **"Upload and Process"**
6. You'll be redirected back to the to the Batch Uploads page `/staff/certification_batch_uploads` with a success message
<img src="docs/assets/Certification_Batch_Uploads_Process.png" width="100%" alt="Upload Certification Batch Uploads Process" />

---

## Step 3: Process the Batch

1. In the Certification Batch Uploads queue, find your uploaded file  
3. Click the **"Process"** button next to your file  
<img src="/docs/assets/Certification_Batch_Uploads_Process.png" width="100%" alt="Upload Certification Batch Uploads Process" />
4. The status will change to "Processing" and then "View Results." Refresh the page if you don't see "View Results" after a few seconds. 
<img src="/docs/assets/Certification_Batch_Uploads_View_Results.png" width="100%" alt="View Results" />
---

## Step 4: View Batch Intake Member Results
 <img src="/docs/assets/Bulk_Intake_Results_Page.png" width="100%" alt="Member Status Results" />

### From the Certification Batch Uploads View

1. Click **"View Results"** to see members and their status from the uploaded file  

 
2. Filter results using the status buttons:
   - All
   - Compliant
   - Exempt
   - Member action required
   - Pending review
  
3. Click on member name or case number on any row to view individual member or case details, respectively

## Step 5: View Batch File Status Results
 <img src="docs/assets/Batch_File_Upload_State_Page.png" width="100%" alt="Batch File Status Results" />

1. Go to the [Certification Batch Uploads](https://medicaid.navateam.com/staff/certification_batch_uploads) page
2. Click on the filename under the **"Filename"** column
3. View batch details including:
   - **Uploaded by:** (email of uploader)
   - **Uploaded at:** (timestamp)
   - **Status:** (Pending, Processing, Completed, or Failed)
   - **Total rows:** (number of rows in CSV)
   - **Processed at:** (completion timestamp)
   - **Successes and errors:** (detailed results)

---

## Troubleshooting

| Issue | Potential Cause | Solution |
|-------|-------|----------|
| Upload fails | Duplicate case numbers | Ensure all `case_number` values are unique |
| Row marked as error | Missing required field | Check that all required fields have values |
| Duplicate certification error | Member/case already exists | This is expected behavior — duplicates are skipped to prevent double-processing |
| Processing stuck | Large file or server load | Wait and refresh — large files process in the background |

---

## Error Recovery

- If some rows fail, you can fix the CSV and re-upload
- Duplicates are automatically skipped on retry (safe to reprocess)
- View error details to see which rows failed and why
