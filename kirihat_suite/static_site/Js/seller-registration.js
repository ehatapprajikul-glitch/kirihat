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
if (!firebase.apps.length) {
    firebase.initializeApp(firebaseConfig);
}
const db = firebase.firestore();
const auth = firebase.auth();
const storage = firebase.storage();

// Form State
let currentStep = 1;
const totalSteps = 4;
const formData = {};
const fileData = {
    gstFile: null,
    panFile: null,
    fssaiFile: null
};

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

    // Check if user is already logged in
    auth.onAuthStateChanged(user => {
        if (user && currentStep === 1) {
            // If already logged in, pre-fill email and perhaps skip step 1?
            // For now, we'll let them stay on step 1 but maybe show a message
            document.getElementById('email').value = user.email;
        }
    });
});

// Event Listeners
function attachEventListeners() {
    nextBtn.addEventListener('click', handleNext);
    backBtn.addEventListener('click', handleBack);
    form.addEventListener('submit', handleSubmit); // Fix: this was attached to 'submit' event but button type is button for next steps

    // Phone number formatting
    const phoneInput = document.getElementById('phone');
    if (phoneInput) {
        phoneInput.addEventListener('input', (e) => {
            e.target.value = e.target.value.replace(/\D/g, '').slice(0, 10);
        });
    }

    // Pincode formatting
    const pincodeInput = document.getElementById('pincode');
    if (pincodeInput) {
        pincodeInput.addEventListener('input', (e) => {
            e.target.value = e.target.value.replace(/\D/g, '').slice(0, 6);
        });
    }

    // File Inputs
    setupFileInput('gstFile', 'gstPreview');
    setupFileInput('panFile', 'panPreview');
    setupFileInput('fssaiFile', 'fssaiPreview');

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

function setupFileInput(inputId, previewId) {
    const input = document.getElementById(inputId);
    const preview = document.getElementById(previewId);

    if (!input || !preview) return;

    input.addEventListener('change', (e) => {
        const file = e.target.files[0];
        if (file) {
            fileData[inputId] = file;

            // Show preview
            if (file.type.startsWith('image/')) {
                const reader = new FileReader();
                reader.onload = (e) => {
                    preview.innerHTML = `<img src="${e.target.result}" alt="Preview">`;
                    preview.classList.add('show');
                };
                reader.readAsDataURL(file);
            } else {
                preview.innerHTML = `<div class="file-info">📄 ${file.name} (${(file.size / 1024).toFixed(1)} KB)</div>`;
                preview.classList.add('show');
            }
        } else {
            fileData[inputId] = null;
            preview.innerHTML = '';
            preview.classList.remove('show');
        }
    });
}

// Navigation Functions
async function handleNext() {
    // Validate current step fields locally first
    if (!validateCurrentStep()) {
        return;
    }

    // Special logic for Step 1 (Create Account)
    if (currentStep === 1) {
        const email = document.getElementById('email').value;
        const password = document.getElementById('password').value;
        const confirmPassword = document.getElementById('confirmPassword').value;

        if (password !== confirmPassword) {
            showFieldError(document.getElementById('confirmPassword'), 'Passwords do not match');
            return;
        }

        // Show loading
        nextBtn.classList.add('loading');
        nextBtn.disabled = true;

        try {
            // Check if user is already logged in with this email
            const currentUser = auth.currentUser;
            if (!currentUser || currentUser.email !== email) {
                // Create user
                await auth.createUserWithEmailAndPassword(email, password);
            }
            // Proceed
            saveCurrentStepData();
            currentStep++;
            showStep(currentStep);
        } catch (error) {
            console.error(error);
            if (error.code === 'auth/email-already-in-use') {
                showFieldError(document.getElementById('email'), 'Email is already registered. Please login or use another email.');
            } else {
                showErrorModal(error.message);
            }
        } finally {
            nextBtn.classList.remove('loading');
            nextBtn.disabled = false;
        }
    } else {
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
    if (currentStepElement) {
        currentStepElement.classList.add('active');
    }

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
    // Password validation
    else if (fieldName === 'password' && value) {
        if (value.length < 6) {
            errorMsg = 'Password must be at least 6 characters';
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
    const inputs = currentStepElement.querySelectorAll('input:not([type="file"]), textarea');

    inputs.forEach(input => {
        if (input.name !== 'password' && input.name !== 'confirmPassword') {
            formData[input.name] = input.value.trim();
        }
    });
}

// Helper: Upload file to Firebase Storage
async function uploadFile(file, path) {
    const ref = storage.ref(path);
    await ref.put(file);
    return await ref.getDownloadURL();
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
        const user = auth.currentUser;
        if (!user) {
            throw new Error('User authentication failed. Please reload and try again.');
        }

        // Upload documents
        const documentUrls = {};
        const userId = user.uid;

        if (fileData.gstFile) {
            documentUrls.gst = await uploadFile(fileData.gstFile, `seller_documents/${userId}/gst_${Date.now()}`);
        }
        if (fileData.panFile) {
            documentUrls.pan = await uploadFile(fileData.panFile, `seller_documents/${userId}/pan_${Date.now()}`);
        }
        if (fileData.fssaiFile) {
            documentUrls.fssai = await uploadFile(fileData.fssaiFile, `seller_documents/${userId}/fssai_${Date.now()}`);
        }

        // Prepare seller data
        const sellerData = {
            user_id: userId, // KEY CHANGE: Use the authenticated user ID
            business_name: formData.businessName,
            owner_name: formData.ownerName,
            email: formData.email,
            phone: formData.phone,
            pincode: formData.pincode,
            address: formData.address,
            city: formData.city,
            state: formData.state,
            serviceable_pincodes: [],
            gst_number: formData.gstNumber || null,
            pan_number: formData.panNumber || null,
            fssai_license: formData.fssaiLicense || null,
            bank_account: {
                account_number: formData.accountNumber,
                ifsc: formData.ifscCode,
                account_holder: formData.accountHolderName
            },
            documents: documentUrls,
            status: 'pending',
            verified: false,
            created_at: firebase.firestore.FieldValue.serverTimestamp(),
            total_products: 0,
            active_products: 0,
            total_sales: 0,
            rating: 0
        };

        // Submit to Firestore
        // We use add() or .doc(userId).set() ? 
        // Logic: Usually one user = one seller account. Let's use user_id as doc ID or distinct doc?
        // seller-registration.html uses db.collection('sellers').add() which generates auto ID.
        // It's safer to use .add() but since we have user_id, we can query it later.

        await db.collection('sellers').add(sellerData);

        // Show success modal
        showSuccessModal();

        // Reset form
        form.reset();
        currentStep = 1;
        // Don't show step 1 since we are done. Success modal handles redirection.

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
    errorMessage.textContent = message || 'An error occurred. Please try again.';
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
