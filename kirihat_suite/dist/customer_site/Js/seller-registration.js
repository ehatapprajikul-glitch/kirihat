// Firebase Configuration
const firebaseConfig = {
    apiKey: "AIzaSyDUaJJWLlmDhJlVHPNNQxQYvDLNmPtKwHg",
    authDomain: "kirihat-ecommerce.firebaseapp.com",
    projectId: "kirihat-ecommerce",
    storageBucket: "kirihat-ecommerce.firebasestorage.app",
    messagingSenderId: "1049866698062",
    appId: "1:1049866698062:web:c4e8e4e8f4e8f4e8f4e8f4"
};

// Initialize Firebase
firebase.initializeApp(firebaseConfig);
const db = firebase.firestore();

// Form State
let currentStep = 1;
const totalSteps = 3;
const formData = {};

// DOM Elements
const form = document.getElementById('sellerRegistrationForm');
const nextBtn = document.getElementById('nextBtn');
const backBtn = document.getElementById('backBtn');
const submitBtn = document.getElementById('submitBtn');
const successModal = document.getElementById('successModal');
const errorModal = document.getElementById('errorModal');
const errorMessage = document.getElementById('errorMessage');

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    updateStepIndicator();
    attachEventListeners();
});

// Event Listeners
function attachEventListeners() {
    nextBtn.addEventListener('click', handleNext);
    backBtn.addEventListener('click', handleBack);
    form.addEventListener('submit', handleSubmit);

    // Phone number formatting
    const phoneInput = document.getElementById('phone');
    phoneInput.addEventListener('input', (e) => {
        e.target.value = e.target.value.replace(/\D/g, '').slice(0, 10);
    });

    // Pincode formatting
    const pincodeInput = document.getElementById('pincode');
    pincodeInput.addEventListener('input', (e) => {
        e.target.value = e.target.value.replace(/\D/g, '').slice(0, 6);
    });

    // GST formatting
    const gstInput = document.getElementById('gstNumber');
    if (gstInput) {
        gstInput.addEventListener('input', (e) => {
            e.target.value = e.target.value.toUpperCase().slice(0, 15);
        });
    }

    // PAN formatting
    const panInput = document.getElementById('panNumber');
    if (panInput) {
        panInput.addEventListener('input', (e) => {
            e.target.value = e.target.value.toUpperCase().slice(0, 10);
        });
    }

    // IFSC formatting
    const ifscInput = document.getElementById('ifscCode');
    if (ifscInput) {
        ifscInput.addEventListener('input', (e) => {
            e.target.value = e.target.value.toUpperCase().slice(0, 11);
        });
    }

    // Real-time validation
    const inputs = form.querySelectorAll('input, textarea');
    inputs.forEach(input => {
        input.addEventListener('blur', () => validateField(input));
        input.addEventListener('input', () => {
            if (input.classList.contains('error')) {
                validateField(input);
            }
        });
    });
}

// Navigation Functions
function handleNext() {
    if (validateCurrentStep()) {
        saveCurrentStepData();
        currentStep++;
        showStep(currentStep);
    }
}

function handleBack() {
    currentStep--;
    showStep(currentStep);
}

function showStep(step) {
    // Hide all steps
    document.querySelectorAll('.form-step').forEach(s => s.classList.remove('active'));

    // Show current step
    const currentStepElement = document.querySelector(`.form-step[data-step="${step}"]`);
    currentStepElement.classList.add('active');

    // Update buttons
    backBtn.style.display = step === 1 ? 'none' : 'flex';
    nextBtn.style.display = step === totalSteps ? 'none' : 'flex';
    submitBtn.style.display = step === totalSteps ? 'flex' : 'none';

    // Update step indicator
    updateStepIndicator();

    // Scroll to top
    window.scrollTo({ top: 0, behavior: 'smooth' });
}

function updateStepIndicator() {
    document.querySelectorAll('.step-item').forEach((item, index) => {
        const stepNumber = index + 1;
        item.classList.remove('active', 'completed');

        if (stepNumber < currentStep) {
            item.classList.add('completed');
        } else if (stepNumber === currentStep) {
            item.classList.add('active');
        }
    });
}

// Validation Functions
function validateCurrentStep() {
    const currentStepElement = document.querySelector(`.form-step[data-step="${currentStep}"]`);
    const inputs = currentStepElement.querySelectorAll('input[required], textarea[required]');
    let isValid = true;

    inputs.forEach(input => {
        if (!validateField(input)) {
            isValid = false;
        }
    });

    return isValid;
}

function validateField(field) {
    const value = field.value.trim();
    const fieldName = field.name;
    let errorMsg = '';

    // Clear previous error
    clearFieldError(field);

    // Required field validation
    if (field.hasAttribute('required') && !value) {
        errorMsg = 'This field is required';
    }
    // Email validation
    else if (fieldName === 'email' && value) {
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(value)) {
            errorMsg = 'Please enter a valid email address';
        }
    }
    // Phone validation
    else if (fieldName === 'phone' && value) {
        if (value.length !== 10) {
            errorMsg = 'Phone number must be 10 digits';
        }
    }
    // Pincode validation
    else if (fieldName === 'pincode' && value) {
        if (value.length !== 6) {
            errorMsg = 'Pincode must be 6 digits';
        }
    }
    // GST validation (optional but if provided, must be valid)
    else if (fieldName === 'gstNumber' && value) {
        const gstRegex = /^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$/;
        if (!gstRegex.test(value)) {
            errorMsg = 'Please enter a valid GST number';
        }
    }
    // PAN validation (optional but if provided, must be valid)
    else if (fieldName === 'panNumber' && value) {
        const panRegex = /^[A-Z]{5}[0-9]{4}[A-Z]{1}$/;
        if (!panRegex.test(value)) {
            errorMsg = 'Please enter a valid PAN number';
        }
    }
    // IFSC validation (optional but if provided, must be valid)
    else if (fieldName === 'ifscCode' && value) {
        const ifscRegex = /^[A-Z]{4}0[A-Z0-9]{6}$/;
        if (!ifscRegex.test(value)) {
            errorMsg = 'Please enter a valid IFSC code';
        }
    }

    if (errorMsg) {
        showFieldError(field, errorMsg);
        return false;
    } else {
        field.classList.add('success');
        return true;
    }
}

function showFieldError(field, message) {
    field.classList.add('error');
    field.classList.remove('success');
    const errorElement = field.parentElement.querySelector('.error-message');
    if (errorElement) {
        errorElement.textContent = message;
        errorElement.classList.add('show');
    }
}

function clearFieldError(field) {
    field.classList.remove('error', 'success');
    const errorElement = field.parentElement.querySelector('.error-message');
    if (errorElement) {
        errorElement.textContent = '';
        errorElement.classList.remove('show');
    }
}

// Data Management
function saveCurrentStepData() {
    const currentStepElement = document.querySelector(`.form-step[data-step="${currentStep}"]`);
    const inputs = currentStepElement.querySelectorAll('input, textarea');

    inputs.forEach(input => {
        formData[input.name] = input.value.trim();
    });
}

// Form Submission
async function handleSubmit(e) {
    e.preventDefault();

    if (!validateCurrentStep()) {
        return;
    }

    saveCurrentStepData();

    // Show loading state
    submitBtn.disabled = true;
    submitBtn.classList.add('loading');

    try {
        // Prepare seller data
        const sellerData = {
            user_id: '', // Will be set after admin approval
            business_name: formData.businessName,
            owner_name: formData.ownerName,
            email: formData.email,
            phone: formData.phone,
            pincode: formData.pincode,
            address: formData.address,
            city: formData.city,
            state: formData.state,
            serviceable_pincodes: [],
            status: 'pending',
            verified: false,
            created_at: firebase.firestore.FieldValue.serverTimestamp(),
            total_products: 0,
            active_products: 0,
            total_sales: 0,
            rating: 0
        };

        // Add optional fields
        if (formData.gstNumber) {
            sellerData.gst_number = formData.gstNumber;
        }
        if (formData.panNumber) {
            sellerData.pan_number = formData.panNumber;
        }
        if (formData.fssaiLicense) {
            sellerData.fssai_license = formData.fssaiLicense;
        }

        // Add bank account if provided
        if (formData.accountNumber && formData.ifscCode && formData.accountHolderName) {
            sellerData.bank_account = {
                account_number: formData.accountNumber,
                ifsc: formData.ifscCode,
                account_holder: formData.accountHolderName
            };
        }

        // Submit to Firestore
        await db.collection('sellers').add(sellerData);

        // Show success modal
        showSuccessModal();

        // Reset form
        form.reset();
        currentStep = 1;
        showStep(1);

    } catch (error) {
        console.error('Error submitting seller registration:', error);
        showErrorModal(error.message);
    } finally {
        submitBtn.disabled = false;
        submitBtn.classList.remove('loading');
    }
}

// Modal Functions
function showSuccessModal() {
    successModal.classList.add('show');
    document.body.style.overflow = 'hidden';
}

function showErrorModal(message) {
    errorMessage.textContent = message || 'An error occurred while submitting your application. Please try again.';
    errorModal.classList.add('show');
    document.body.style.overflow = 'hidden';
}

function closeErrorModal() {
    errorModal.classList.remove('show');
    document.body.style.overflow = '';
}

// Close modal when clicking outside
window.addEventListener('click', (e) => {
    if (e.target === successModal) {
        successModal.classList.remove('show');
        document.body.style.overflow = '';
        window.location.href = '/';
    }
    if (e.target === errorModal) {
        closeErrorModal();
    }
});
