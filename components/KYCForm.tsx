import { useState } from 'react';

interface KYCFormData {
  fullName: string;
  dateOfBirth: string;
  nationality: string;
  documentType: string;
  documentNumber: string;
  email: string;
}

interface KYCFormProps {
  onSubmit: (data: KYCFormData) => void;
  walletAddress: string;
}

export function KYCForm({ onSubmit, walletAddress }: KYCFormProps) {
  const [form, setForm] = useState<KYCFormData>({
    fullName: '',
    dateOfBirth: '',
    nationality: '',
    documentType: 'passport',
    documentNumber: '',
    email: '',
  });

  function handleChange(e: React.ChangeEvent<HTMLInputElement | HTMLSelectElement>) {
    setForm({ ...form, [e.target.name]: e.target.value });
  }

  function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    onSubmit(form);
  }

  return (
    <form onSubmit={handleSubmit} className="kyc-form">
      <h2>KYC Verification</h2>
      <p>Wallet: {walletAddress}</p>

      <label>Full Name</label>
      <input name="fullName" value={form.fullName} onChange={handleChange} required />

      <label>Date of Birth</label>
      <input name="dateOfBirth" type="date" value={form.dateOfBirth} onChange={handleChange} required />

      <label>Nationality</label>
      <input name="nationality" value={form.nationality} onChange={handleChange} required />

      <label>Document Type</label>
      <select name="documentType" value={form.documentType} onChange={handleChange}>
        <option value="passport">Passport</option>
        <option value="national-id">National ID</option>
        <option value="drivers-license">Driver's License</option>
      </select>

      <label>Document Number</label>
      <input name="documentNumber" value={form.documentNumber} onChange={handleChange} required />

      <label>Email</label>
      <input name="email" type="email" value={form.email} onChange={handleChange} required />

      <button type="submit">Submit KYC</button>
    </form>
  );
}
